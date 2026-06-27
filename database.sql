-- 1. PROFILES (Teacher/Admin Info)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  role TEXT DEFAULT 'teacher' CHECK (role IN ('teacher', 'admin')),
  school_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 2. CLASSES
CREATE TABLE classes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  teacher_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  grade_level TEXT,
  subject TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE classes ENABLE ROW LEVEL SECURITY;

-- 3. STUDENTS
CREATE TABLE students (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE NOT NULL,
  full_name TEXT NOT NULL,
  roll_number TEXT,
  parent_whatsapp TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- 4. EXAMS
CREATE TABLE exams (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  subject TEXT,
  max_score INTEGER DEFAULT 100,
  answer_key TEXT, -- Raw answer key text or reference
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE exams ENABLE ROW LEVEL SECURITY;

-- 5. SUBMISSIONS (Answer Sheets)
CREATE TABLE submissions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  exam_id UUID REFERENCES exams(id) ON DELETE CASCADE NOT NULL,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE NOT NULL,
  image_url TEXT, -- URL to Supabase Storage
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'graded', 'error')),
  ocr_text TEXT, -- Raw text extracted from image
  is_flagged BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE submissions ENABLE ROW LEVEL SECURITY;

-- 6. GRADING RESULTS
CREATE TABLE grading_results (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  submission_id UUID REFERENCES submissions(id) ON DELETE CASCADE NOT NULL,
  total_score NUMERIC(5,2),
  percentage NUMERIC(5,2),
  grade TEXT,
  feedback_english TEXT,
  feedback_hindi TEXT,
  feedback_gujarati TEXT,
  question_scores JSONB, -- Array of {q, scored, max, feedback}
  strengths JSONB, -- Array of strings
  improvements JSONB, -- Array of strings
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE grading_results ENABLE ROW LEVEL SECURITY;

-- 7. STUDY PLANS
CREATE TABLE study_plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE NOT NULL,
  grading_result_id UUID REFERENCES grading_results(id) ON DELETE SET NULL,
  plan_data JSONB, -- The 7-day study plan structure
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE study_plans ENABLE ROW LEVEL SECURITY;

-- RLS POLICIES

-- Profiles: Users can only view/edit their own profile
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Classes: Teachers can only view/manage their own classes
CREATE POLICY "Teachers can view own classes" ON classes FOR SELECT USING (auth.uid() = teacher_id);
CREATE POLICY "Teachers can insert own classes" ON classes FOR INSERT WITH CHECK (auth.uid() = teacher_id);
CREATE POLICY "Teachers can update own classes" ON classes FOR UPDATE USING (auth.uid() = teacher_id);
CREATE POLICY "Teachers can delete own classes" ON classes FOR DELETE USING (auth.uid() = teacher_id);

-- Students: Accessible via class -> teacher
CREATE POLICY "Teachers can view students in their classes" ON students 
  FOR SELECT USING (EXISTS (SELECT 1 FROM classes WHERE classes.id = students.class_id AND classes.teacher_id = auth.uid()));

CREATE POLICY "Teachers can manage students in their classes" ON students 
  FOR ALL USING (EXISTS (SELECT 1 FROM classes WHERE classes.id = students.class_id AND classes.teacher_id = auth.uid()));

-- Exams: Accessible via class -> teacher
CREATE POLICY "Teachers can manage exams in their classes" ON exams 
  FOR ALL USING (EXISTS (SELECT 1 FROM classes WHERE classes.id = exams.class_id AND classes.teacher_id = auth.uid()));

-- Submissions: Accessible via exam -> class -> teacher
CREATE POLICY "Teachers can manage submissions" ON submissions 
  FOR ALL USING (EXISTS (
    SELECT 1 FROM exams 
    JOIN classes ON classes.id = exams.class_id 
    WHERE exams.id = submissions.exam_id AND classes.teacher_id = auth.uid()
  ));

-- Grading Results: Accessible via submission -> exam -> class -> teacher
CREATE POLICY "Teachers can manage grading results" ON grading_results 
  FOR ALL USING (EXISTS (
    SELECT 1 FROM submissions 
    JOIN exams ON exams.id = submissions.exam_id
    JOIN classes ON classes.id = exams.class_id 
    WHERE submissions.id = grading_results.submission_id AND classes.teacher_id = auth.uid()
  ));

-- Study Plans: Accessible via student -> class -> teacher
CREATE POLICY "Teachers can manage study plans" ON study_plans 
  FOR ALL USING (EXISTS (
    SELECT 1 FROM students
    JOIN classes ON classes.id = students.class_id
    WHERE students.id = study_plans.student_id AND classes.teacher_id = auth.uid()
  ));

-- 8. AUTH TRIGGER (Auto-create profile)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- UPDATE: Add welcome_sent column to track onboarding emails
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS welcome_sent BOOLEAN DEFAULT FALSE;
