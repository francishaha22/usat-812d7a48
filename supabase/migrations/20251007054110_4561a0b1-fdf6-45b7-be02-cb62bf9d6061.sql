-- Fix 1: Update handle_new_user() trigger to insert into both profiles AND user_roles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Insert into profiles table
  INSERT INTO public.profiles (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    'student'
  );
  
  -- Insert into user_roles table (critical for RLS)
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'student'::user_role);
  
  RETURN NEW;
END;
$$;

-- Fix 2: Migrate existing profile roles to user_roles table
-- Handle the type conversion from app_role to user_role
INSERT INTO public.user_roles (user_id, role)
SELECT 
  id, 
  CASE 
    WHEN role::text = 'admin' THEN 'admin'::user_role
    WHEN role::text = 'teacher' THEN 'teacher'::user_role
    WHEN role::text = 'student' THEN 'student'::user_role
    ELSE 'student'::user_role
  END as role
FROM public.profiles
WHERE NOT EXISTS (
  SELECT 1 FROM public.user_roles WHERE user_roles.user_id = profiles.id
);

-- Fix 3: Update get_user_role() function to have explicit search_path
CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid)
RETURNS app_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = user_id;
$$;

-- Fix 4: Update storage policies for learning materials with class-based access control
-- Drop existing overly permissive policies
DROP POLICY IF EXISTS "Users can view materials for their classes" ON storage.objects;
DROP POLICY IF EXISTS "Teachers can upload materials" ON storage.objects;
DROP POLICY IF EXISTS "Teachers can update their materials" ON storage.objects;
DROP POLICY IF EXISTS "Teachers can delete their materials" ON storage.objects;

-- Create new policies with proper class enrollment checks
-- Policy for students: can only view materials for classes they're enrolled in
CREATE POLICY "Students can view materials for enrolled classes"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'learning-materials' AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT class_id::text::uuid 
    FROM class_students 
    WHERE student_id = auth.uid()
  )
);

-- Policy for teachers: can view materials for their classes
CREATE POLICY "Teachers can view materials for their classes"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'learning-materials' AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id 
    FROM classes 
    WHERE teacher_id = auth.uid()
  )
);

-- Policy for admins: can view all materials
CREATE POLICY "Admins can view all materials"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'learning-materials' AND
  has_role(auth.uid(), 'admin')
);

-- Teachers can upload to their class folders
CREATE POLICY "Teachers can upload materials to their classes"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'learning-materials' AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id 
    FROM classes 
    WHERE teacher_id = auth.uid()
  )
);

-- Teachers can update materials in their class folders
CREATE POLICY "Teachers can update their class materials"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'learning-materials' AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id 
    FROM classes 
    WHERE teacher_id = auth.uid()
  )
);

-- Teachers can delete materials from their class folders
CREATE POLICY "Teachers can delete their class materials"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'learning-materials' AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id 
    FROM classes 
    WHERE teacher_id = auth.uid()
  )
);

-- Fix 5: Add similar policies for assessment-files bucket
DROP POLICY IF EXISTS "Users can view assessment files for their classes" ON storage.objects;
DROP POLICY IF EXISTS "Students can upload assessment submissions" ON storage.objects;
DROP POLICY IF EXISTS "Teachers can upload assessment files" ON storage.objects;

-- Students can view assessment files for enrolled classes
CREATE POLICY "Students can view assessment files for enrolled classes"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'assessment-files' AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT class_id::text::uuid 
    FROM class_students 
    WHERE student_id = auth.uid()
  )
);

-- Teachers can view assessment files for their classes
CREATE POLICY "Teachers can view assessment files for their classes"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'assessment-files' AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id 
    FROM classes 
    WHERE teacher_id = auth.uid()
  )
);

-- Students can upload their submissions
CREATE POLICY "Students can upload assessment submissions"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'assessment-files' AND
  (storage.foldername(name))[2] = auth.uid()::text
);

-- Teachers can upload assessment files to their classes
CREATE POLICY "Teachers can upload assessment files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'assessment-files' AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id 
    FROM classes 
    WHERE teacher_id = auth.uid()
  )
);

-- Fix 6: Add length constraints to prevent database bloat
ALTER TABLE messages ADD CONSTRAINT messages_content_length CHECK (char_length(content) <= 10000);
ALTER TABLE announcements ADD CONSTRAINT announcements_content_length CHECK (char_length(content) <= 50000);
ALTER TABLE assessment_submissions ADD CONSTRAINT submissions_feedback_length CHECK (char_length(feedback) <= 5000);