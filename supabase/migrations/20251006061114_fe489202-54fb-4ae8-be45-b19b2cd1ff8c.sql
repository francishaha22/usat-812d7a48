-- First, fix the security issue: create separate user_roles table
CREATE TYPE public.user_role AS ENUM ('admin', 'teacher', 'student');

-- Create user_roles table
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role user_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  UNIQUE (user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Security definer function to check roles (prevents privilege escalation)
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role user_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  )
$$;

-- Migrate existing roles from profiles to user_roles
INSERT INTO public.user_roles (user_id, role)
SELECT id, role::text::user_role
FROM public.profiles;

-- RLS policies for user_roles
CREATE POLICY "Users can view their own roles"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins can manage all roles"
  ON public.user_roles FOR ALL
  TO authenticated
  USING (has_role(auth.uid(), 'admin'));

-- Create attendance table
CREATE TABLE public.attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE NOT NULL,
  student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  time_in TIMESTAMP WITH TIME ZONE DEFAULT now(),
  status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
  method TEXT CHECK (method IN ('manual', 'qr_code')),
  remarks TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  UNIQUE (class_id, student_id, date)
);

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

-- Create learning_materials table
CREATE TABLE public.learning_materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE NOT NULL,
  teacher_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  file_url TEXT,
  file_type TEXT CHECK (file_type IN ('pdf', 'ppt', 'video', 'document', 'other')),
  topic TEXT,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

ALTER TABLE public.learning_materials ENABLE ROW LEVEL SECURITY;

-- Create assessments table
CREATE TABLE public.assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE NOT NULL,
  teacher_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL CHECK (type IN ('quiz', 'exam', 'assignment', 'performance_task')),
  total_points DECIMAL(5,2) NOT NULL,
  weight DECIMAL(5,2) DEFAULT 1.0,
  deadline TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;

-- Create assessment_submissions table
CREATE TABLE public.assessment_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID REFERENCES public.assessments(id) ON DELETE CASCADE NOT NULL,
  student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  score DECIMAL(5,2),
  submitted_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  graded_at TIMESTAMP WITH TIME ZONE,
  feedback TEXT,
  UNIQUE (assessment_id, student_id)
);

ALTER TABLE public.assessment_submissions ENABLE ROW LEVEL SECURITY;

-- Create notifications table
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('announcement', 'grade', 'deadline', 'attendance', 'general')),
  is_read BOOLEAN DEFAULT FALSE,
  link TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Create chat_rooms table
CREATE TABLE public.chat_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('direct', 'group', 'class')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;

-- Create chat_members table
CREATE TABLE public.chat_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES public.chat_rooms(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  UNIQUE (room_id, user_id)
);

ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;

-- Create messages table
CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES public.chat_rooms(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for attendance
CREATE POLICY "Teachers can manage attendance for their classes"
  ON public.attendance FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.classes
      WHERE classes.id = attendance.class_id
        AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Students can view their own attendance"
  ON public.attendance FOR SELECT
  TO authenticated
  USING (student_id = auth.uid());

CREATE POLICY "Admins can view all attendance"
  ON public.attendance FOR SELECT
  TO authenticated
  USING (has_role(auth.uid(), 'admin'));

-- RLS Policies for learning_materials
CREATE POLICY "Teachers can manage materials for their classes"
  ON public.learning_materials FOR ALL
  TO authenticated
  USING (teacher_id = auth.uid());

CREATE POLICY "Students can view materials for their enrolled classes"
  ON public.learning_materials FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.class_students
      WHERE class_students.class_id = learning_materials.class_id
        AND class_students.student_id = auth.uid()
    )
  );

CREATE POLICY "Admins can view all materials"
  ON public.learning_materials FOR SELECT
  TO authenticated
  USING (has_role(auth.uid(), 'admin'));

-- RLS Policies for assessments
CREATE POLICY "Teachers can manage assessments for their classes"
  ON public.assessments FOR ALL
  TO authenticated
  USING (teacher_id = auth.uid());

CREATE POLICY "Students can view assessments for their classes"
  ON public.assessments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.class_students
      WHERE class_students.class_id = assessments.class_id
        AND class_students.student_id = auth.uid()
    )
  );

CREATE POLICY "Admins can view all assessments"
  ON public.assessments FOR SELECT
  TO authenticated
  USING (has_role(auth.uid(), 'admin'));

-- RLS Policies for assessment_submissions
CREATE POLICY "Students can manage their own submissions"
  ON public.assessment_submissions FOR ALL
  TO authenticated
  USING (student_id = auth.uid());

CREATE POLICY "Teachers can view submissions for their classes"
  ON public.assessment_submissions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.assessments
      JOIN public.classes ON assessments.class_id = classes.id
      WHERE assessments.id = assessment_submissions.assessment_id
        AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Teachers can grade submissions"
  ON public.assessment_submissions FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.assessments
      JOIN public.classes ON assessments.class_id = classes.id
      WHERE assessments.id = assessment_submissions.assessment_id
        AND classes.teacher_id = auth.uid()
    )
  );

-- RLS Policies for notifications
CREATE POLICY "Users can view their own notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their own notifications"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Teachers and admins can create notifications"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (
    has_role(auth.uid(), 'teacher') OR has_role(auth.uid(), 'admin')
  );

-- RLS Policies for chat_rooms
CREATE POLICY "Users can view rooms they are members of"
  ON public.chat_rooms FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_members
      WHERE chat_members.room_id = chat_rooms.id
        AND chat_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Teachers and admins can create chat rooms"
  ON public.chat_rooms FOR INSERT
  TO authenticated
  WITH CHECK (
    has_role(auth.uid(), 'teacher') OR has_role(auth.uid(), 'admin')
  );

-- RLS Policies for chat_members
CREATE POLICY "Users can view members of their rooms"
  ON public.chat_members FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_members cm
      WHERE cm.room_id = chat_members.room_id
        AND cm.user_id = auth.uid()
    )
  );

-- RLS Policies for messages
CREATE POLICY "Users can view messages in their rooms"
  ON public.messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_members
      WHERE chat_members.room_id = messages.room_id
        AND chat_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can send messages to their rooms"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.chat_members
      WHERE chat_members.room_id = messages.room_id
        AND chat_members.user_id = auth.uid()
    )
  );

-- Create storage buckets for files
INSERT INTO storage.buckets (id, name, public) VALUES ('learning-materials', 'learning-materials', false);
INSERT INTO storage.buckets (id, name, public) VALUES ('assessment-files', 'assessment-files', false);

-- Storage policies for learning materials
CREATE POLICY "Teachers can upload materials"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'learning-materials' AND
    has_role(auth.uid(), 'teacher')
  );

CREATE POLICY "Users can view materials for their classes"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'learning-materials');

-- Storage policies for assessment files
CREATE POLICY "Students can upload assessment files"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'assessment-files' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Teachers and students can view assessment files"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'assessment-files');

-- Update trigger for learning_materials
CREATE TRIGGER update_learning_materials_updated_at
  BEFORE UPDATE ON public.learning_materials
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Enable realtime for chat
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;