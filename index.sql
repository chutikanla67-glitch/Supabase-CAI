-- ============================================================================
-- สคริปต์ตั้งค่าฐานข้อมูลสำหรับ CAI การออกแบบและเทคโนโลยี (ว21013) โรงเรียนแมวน้อย
-- ============================================================================

-- 1. สร้างตารางข้อมูลหลัก (Tables)
CREATE TABLE IF NOT EXISTS public.teachers (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.students (
    id text PRIMARY KEY, -- รหัสนักเรียน 11 หลัก
    title text NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    section text NOT NULL,
    user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    photo_path text,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.attempts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('pre', 'post')),
    score integer NOT NULL CHECK (score BETWEEN 0 AND 10),
    answers jsonb NOT NULL,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT unique_user_kind UNIQUE (user_id, kind)
);

CREATE TABLE IF NOT EXISTS public.progress (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    unit integer NOT NULL CHECK (unit BETWEEN 1 AND 5),
    done boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT unique_user_unit UNIQUE (user_id, unit)
);

CREATE TABLE IF NOT EXISTS public.submissions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    unit integer NOT NULL CHECK (unit BETWEEN 1 AND 5),
    kind text NOT NULL CHECK (kind IN ('link', 'file')),
    url text,
    storage_path text,
    note text,
    score numeric(5,2) CHECK (score IS NULL OR (score >= 0 AND score <= 100)),
    teacher_comment text,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.materials (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    title text NOT NULL,
    kind text NOT NULL CHECK (kind IN ('file', 'link', 'video')),
    url text,
    storage_path text,
    file_name text,
    created_at timestamptz DEFAULT now()
);

-- 2. ฟังก์ชันตรวจสอบสิทธิ์ผู้สอน (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.teachers WHERE user_id = auth.uid()
  );
$$;

-- 3. Trigger ตรวจสอบและผูกสิทธิ์นักเรียนเมื่อสมัครสมาชิก
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  student_code text;
BEGIN
  -- ดึงรหัสนักเรียน 11 หลักจากรูปแบบอีเมล <รหัส>@student.maeonoi.ac.th
  student_code := substring(NEW.email from '^([0-9]{11})@');
  
  -- ถ้าเป็นอีเมลนักเรียน ให้ตรวจสอบรายชื่อ
  IF student_code IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.students WHERE id = student_code AND user_id IS NULL) THEN
      UPDATE public.students SET user_id = NEW.id WHERE id = student_code;
    ELSE
      RAISE EXCEPTION 'รหัสนักเรียน % ไม่พบในระบบ หรือได้ลงทะเบียนบัญชีไปแล้ว', student_code;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Trigger ป้องกันนักเรียนแอบแก้ไขคะแนนหรือข้อเสนอแนะงานส่ง
CREATE OR REPLACE FUNCTION public.prevent_student_grading_tamper()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_teacher() THEN
    IF (NEW.score IS DISTINCT FROM OLD.score) OR (NEW.teacher_comment IS DISTINCT FROM OLD.teacher_comment) THEN
      RAISE EXCEPTION 'ผู้เรียนไม่มีสิทธิ์แก้ไขคะแนนหรือข้อเสนอแนะของผู้สอน';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_grading_tamper ON public.submissions;
CREATE TRIGGER trg_prevent_grading_tamper
  BEFORE UPDATE ON public.submissions
  FOR EACH ROW EXECUTE FUNCTION public.prevent_student_grading_tamper();

-- 5. การตั้งค่า Row Level Security (RLS)
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;

-- ถอนสิทธิ์ anon และจำกัดสิทธิ์ authenticated
REVOKE ALL ON public.teachers FROM anon, authenticated;
REVOKE ALL ON public.students FROM anon, authenticated;
REVOKE ALL ON public.attempts FROM anon, authenticated;
REVOKE ALL ON public.progress FROM anon, authenticated;
REVOKE ALL ON public.submissions FROM anon, authenticated;
REVOKE ALL ON public.materials FROM anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.teachers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.students TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.attempts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.progress TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.submissions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.materials TO authenticated;

-- นโยบาย RLS ตาราง teachers
CREATE POLICY teachers_select ON public.teachers FOR SELECT TO authenticated USING (true);

-- นโยบาย RLS ตาราง students
CREATE POLICY students_select ON public.students FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_teacher());
CREATE POLICY students_update ON public.students FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- นโยบาย RLS ตาราง attempts
CREATE POLICY attempts_select ON public.attempts FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_teacher());
CREATE POLICY attempts_insert ON public.attempts FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

-- นโยบาย RLS ตาราง progress
CREATE POLICY progress_select ON public.progress FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_teacher());
CREATE POLICY progress_insert ON public.progress FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY progress_update ON public.progress FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- นโยบาย RLS ตาราง submissions
CREATE POLICY submissions_select ON public.submissions FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_teacher());
CREATE POLICY submissions_insert ON public.submissions FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY submissions_update ON public.submissions FOR UPDATE TO authenticated USING (user_id = auth.uid() OR public.is_teacher());
CREATE POLICY submissions_delete ON public.submissions FOR DELETE TO authenticated USING (user_id = auth.uid() OR public.is_teacher());

-- นโยบาย RLS ตาราง materials
CREATE POLICY materials_select ON public.materials FOR SELECT TO authenticated USING (true);
CREATE POLICY materials_insert ON public.materials FOR INSERT TO authenticated WITH CHECK (public.is_teacher());
CREATE POLICY materials_update ON public.materials FOR UPDATE TO authenticated USING (public.is_teacher());
CREATE POLICY materials_delete ON public.materials FOR DELETE TO authenticated USING (public.is_teacher());

-- 6. สร้าง View สรุปผลสำหรับผู้สอน (security_invoker = true)
CREATE OR REPLACE VIEW public.results WITH (security_invoker = true) AS
SELECT 
  s.id AS student_id,
  s.title,
  s.first_name,
  s.last_name,
  s.section,
  s.photo_path,
  att_pre.score AS pre_score,
  att_post.score AS post_score,
  CASE 
    WHEN att_pre.score IS NOT NULL AND att_post.score IS NOT NULL THEN
      CASE 
        WHEN (10 - att_pre.score) = 0 THEN 0.00
        ELSE ROUND(((att_post.score - att_pre.score)::numeric / (10 - att_pre.score)::numeric), 2)
      END
    ELSE NULL
  END AS normalized_gain,
  (SELECT COUNT(DISTINCT unit) FROM public.progress p WHERE p.user_id = s.user_id AND p.done = true) AS completed_units
FROM public.students s
LEFT JOIN public.attempts att_pre ON att_pre.user_id = s.user_id AND att_pre.kind = 'pre'
LEFT JOIN public.attempts att_post ON att_post.user_id = s.user_id AND att_post.kind = 'post';

GRANT SELECT ON public.results TO authenticated;

-- 7. สร้าง Private Storage Buckets และนโยบายควบคุมการเข้าถึง
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('photos', 'photos', false, 2097152, ARRAY['image/png', 'image/jpeg']),
  ('submissions', 'submissions', false, 20971520, ARRAY['image/png', 'image/jpeg', 'application/pdf', 'video/mp4']),
  ('materials', 'materials', false, 52428800, ARRAY['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'])
ON CONFLICT (id) DO UPDATE SET 
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Bucket Policies: photos
CREATE POLICY "photos_select" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'photos' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_teacher())
);
CREATE POLICY "photos_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (
  bucket_id = 'photos' AND (storage.foldername(name))[1] = auth.uid()::text
);
CREATE POLICY "photos_update" ON storage.objects FOR UPDATE TO authenticated USING (
  bucket_id = 'photos' AND (storage.foldername(name))[1] = auth.uid()::text
);
CREATE POLICY "photos_delete" ON storage.objects FOR DELETE TO authenticated USING (
  bucket_id = 'photos' AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Bucket Policies: submissions
CREATE POLICY "submissions_select" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'submissions' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_teacher())
);
CREATE POLICY "submissions_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (
  bucket_id = 'submissions' AND (storage.foldername(name))[1] = auth.uid()::text
);
CREATE POLICY "submissions_update" ON storage.objects FOR UPDATE TO authenticated USING (
  bucket_id = 'submissions' AND (storage.foldername(name))[1] = auth.uid()::text
);
CREATE POLICY "submissions_delete" ON storage.objects FOR DELETE TO authenticated USING (
  bucket_id = 'submissions' AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Bucket Policies: materials
CREATE POLICY "materials_select" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'materials'
);
CREATE POLICY "materials_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (
  bucket_id = 'materials' AND public.is_teacher()
);
CREATE POLICY "materials_update" ON storage.objects FOR UPDATE TO authenticated USING (
  bucket_id = 'materials' AND public.is_teacher()
);
CREATE POLICY "materials_delete" ON storage.objects FOR DELETE TO authenticated USING (
  bucket_id = 'materials' AND public.is_teacher()
);

-- 8. ข้อมูลจำลองรายชื่อนักเรียน (6 รายชื่อ)
-- หมายเหตุวิธีนำเข้ารายชื่อจริงผ่าน CSV:
-- ให้ไปที่ Supabase Dashboard -> Table Editor -> เลือกตาราง students -> กด "Import CSV"
-- นำเข้าไฟล์ CSV ที่มีโครงสร้างคอลัมน์: id (11 หลัก), title, first_name, last_name, section
INSERT INTO public.students (id, title, first_name, last_name, section) VALUES
  ('66010100001', 'นาย', 'สมชาย', 'ใจดี', 'ม.2/1'),
  ('66010100002', 'นางสาว', 'สมหญิง', 'รักเรียน', 'ม.2/1'),
  ('66010100003', 'เด็กชาย', 'ก้องเกียรติ', 'เรียนดี', 'ม.2/1'),
  ('66010100004', 'เด็กหญิง', 'มณีรัตน์', 'สดใส', 'ม.2/2'),
  ('66010100005', 'นาย', 'ธนกฤต', 'มีปัญญา', 'ม.2/2'),
  ('66010100006', 'นางสาว', 'พรทิพย์', 'ตั้งใจ', 'ม.2/2')
ON CONFLICT (id) DO NOTHING;

-- 9. คำสั่งตั้งค่าผู้สอน (ปิดคอมเมนต์ไว้ ให้ผู้สอนใส่อีเมล/User ID หลังจากสมัครสมาชิกแล้วเปิดรัน)
-- INSERT INTO public.teachers (user_id) VALUES ('<ใส่_USER_UUID_ของผู้สอนที่ได้จาก_Authentication_Tab>') ON CONFLICT DO NOTHING;