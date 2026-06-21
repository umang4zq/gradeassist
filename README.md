# GradeAssist AI

AI-powered exam grading platform built for Indian classrooms, with handwriting OCR support for Hindi, Gujarati, and English answer sheets.

## Problem

Manual exam grading is slow, inconsistent, and especially painful for handwritten regional-language answer sheets. GradeAssist automates the pipeline from scanned answer sheet to graded result.

## Features

- Multi-language handwriting OCR (Hindi / Gujarati / English)
- AI-powered grading with rubric-based scoring
- 4-column grading workspace for teacher review and overrides
- WhatsApp delivery of results to students/parents
- Multi-model fallback for OCR reliability

## Tech Stack

- **Frontend/Backend:** Next.js
- **OCR (Vision):** Gemini 2.0 Flash, with multi-model fallback
- **Grading model:** Llama 3.3 70B via NVIDIA NIM
- **Database/Auth:** Supabase
- **Deployment:** AWS EC2, managed with PM2

## Architecture

1. Answer sheet image uploaded
2. Gemini 2.0 Flash performs OCR extraction (with fallback models if confidence is low)
3. Extracted text passed to Llama 3.3 70B (via NVIDIA NIM) for grading against the answer key/rubric
4. Teacher reviews/overrides scores in the grading workspace
5. Results delivered via WhatsApp

## Setup

\`\`\`bash
git clone https://github.com/umang4zq/gradeassist.git
cd gradeassist
npm install
\`\`\`

Create a `.env.local` file with:
\`\`\`
GEMINI_API_KEY=
NVIDIA_NIM_API_KEY=
SUPABASE_URL=
SUPABASE_ANON_KEY=
\`\`\`

\`\`\`bash
npm run dev
\`\`\`

## Status

Actively in production use, deployed via PM2 on AWS EC2.
