-- Create roles enum
CREATE TYPE public.app_role AS ENUM ('admin', 'teacher', 'student');

-- Create profiles table (extends auth.users with role and additional info)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role app_role NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create classes table
CREATE TABLE public.classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create class_students junction table
CREATE TABLE public.class_students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(class_id, student_id)
);

-- Create grades table
CREATE TABLE public.grades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  grade VARCHAR(10) NOT NULL,
  remarks TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create announcements table
CREATE TABLE public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Create security definer function to check user role
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS app_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = user_id;
$$;

-- RLS Policies for profiles table
CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON public.profiles FOR SELECT
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admins can insert profiles"
  ON public.profiles FOR INSERT
  WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admins can update profiles"
  ON public.profiles FOR UPDATE
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admins can delete profiles"
  ON public.profiles FOR DELETE
  USING (public.get_user_role(auth.uid()) = 'admin');

-- RLS Policies for classes table
CREATE POLICY "Admins can view all classes"
  ON public.classes FOR SELECT
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Teachers can view their own classes"
  ON public.classes FOR SELECT
  USING (teacher_id = auth.uid());

CREATE POLICY "Students can view their enrolled classes"
  ON public.classes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.class_students
      WHERE class_id = classes.id AND student_id = auth.uid()
    )
  );

CREATE POLICY "Admins can insert classes"
  ON public.classes FOR INSERT
  WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Teachers can insert their own classes"
  ON public.classes FOR INSERT
  WITH CHECK (teacher_id = auth.uid() AND public.get_user_role(auth.uid()) = 'teacher');

CREATE POLICY "Admins can update classes"
  ON public.classes FOR UPDATE
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Teachers can update their own classes"
  ON public.classes FOR UPDATE
  USING (teacher_id = auth.uid());

CREATE POLICY "Admins can delete classes"
  ON public.classes FOR DELETE
  USING (public.get_user_role(auth.uid()) = 'admin');

-- RLS Policies for class_students table
CREATE POLICY "Admins can view all class enrollments"
  ON public.class_students FOR SELECT
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Teachers can view enrollments for their classes"
  ON public.class_students FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.classes
      WHERE classes.id = class_students.class_id AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Students can view their own enrollments"
  ON public.class_students FOR SELECT
  USING (student_id = auth.uid());

CREATE POLICY "Admins can insert class enrollments"
  ON public.class_students FOR INSERT
  WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admins can delete class enrollments"
  ON public.class_students FOR DELETE
  USING (public.get_user_role(auth.uid()) = 'admin');

-- RLS Policies for grades table
CREATE POLICY "Admins can view all grades"
  ON public.grades FOR SELECT
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Teachers can view grades for their classes"
  ON public.grades FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.classes
      WHERE classes.id = grades.class_id AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Students can view their own grades"
  ON public.grades FOR SELECT
  USING (student_id = auth.uid());

CREATE POLICY "Teachers can insert grades for their classes"
  ON public.grades FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.classes
      WHERE classes.id = class_id AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Teachers can update grades for their classes"
  ON public.grades FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.classes
      WHERE classes.id = grades.class_id AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Admins can delete grades"
  ON public.grades FOR DELETE
  USING (public.get_user_role(auth.uid()) = 'admin');

-- RLS Policies for announcements table
CREATE POLICY "Admins can view all announcements"
  ON public.announcements FOR SELECT
  USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Teachers can view all announcements"
  ON public.announcements FOR SELECT
  USING (public.get_user_role(auth.uid()) = 'teacher');

CREATE POLICY "Students can view announcements for their classes"
  ON public.announcements FOR SELECT
  USING (
    class_id IS NULL OR
    EXISTS (
      SELECT 1 FROM public.class_students
      WHERE class_students.class_id = announcements.class_id 
      AND class_students.student_id = auth.uid()
    )
  );

CREATE POLICY "Teachers can insert announcements"
  ON public.announcements FOR INSERT
  WITH CHECK (teacher_id = auth.uid() AND public.get_user_role(auth.uid()) = 'teacher');

CREATE POLICY "Teachers can update their own announcements"
  ON public.announcements FOR UPDATE
  USING (teacher_id = auth.uid());

CREATE POLICY "Teachers can delete their own announcements"
  ON public.announcements FOR DELETE
  USING (teacher_id = auth.uid());

CREATE POLICY "Admins can delete announcements"
  ON public.announcements FOR DELETE
  USING (public.get_user_role(auth.uid()) = 'admin');

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for profiles table
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Insert seed admin user (will be created after first manual signup)
-- Note: First user must sign up manually, then we'll update their role to admin