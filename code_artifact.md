# ระบบสื่อการเรียนรู้คอมพิวเตอร์ช่วยสอน (CAI) เรื่อง เทคโนโลยีความจริงเสริม (AR)
**รายวิชาการออกแบบและเทคโนโลยี (ว21013) ชั้นมัธยมศึกษาปีที่ 2 โรงเรียนแมวน้อย**

ระบบสื่อการเรียนรู้ CAI พัฒนาขึ้นในรูปแบบ Single-Page Web Application ร่วมกับเทคโนโลยี **Supabase (Backend-as-a-Service)** และ **Tailwind CSS** สำหรับการจัดการเรียนรู้ การประเมินผลการเรียนรู้แบบวัดพัฒนาการ (Normalized Gain) และการปฏิสัมพันธ์งานปฏิบัติ WebAR

---

## 📁 โครงสร้างไฟล์ในโครงการ

1. **`courseware.html`** — ไฟล์หลักสำหรับแสดงผลและประมวลผลหน้าเว็บ (Single-File App) รวม HTML, Tailwind CSS, JavaScript, Web Component `<model-viewer>` และการเชื่อมต่อ Supabase API
2. **`setup.sql`** — สคริปต์ SQL สำหรับสร้างโครงสร้างฐานข้อมูล (Tables, Views), ระบบรักษาความปลอดภัย Row Level Security (RLS), Trigger การตรวจสอบสิทธิ์ และ Private Storage Buckets
3. **`README.md`** — เอกสารคู่มือการติดตั้ง ตั้งค่า และใช้งานระบบ (ไฟล์นี้)

---

## 🚀 ขั้นตอนการติดตั้งและตั้งค่าระบบ (Setup Guide)

### ขั้นตอนที่ 1: การเตรียมฐานข้อมูล Supabase

1. สมัครใช้งานและสร้างโครงการใหม่ที่ [Supabase.com](https://supabase.com)
2. ไปที่เมนู **SQL Editor** ใน Supabase Dashboard
3. คัดลอกเนื้อหาทั้งหมดจากไฟล์ `setup.sql` ไปวางใน SQL Editor แล้วกด **Run**
4. ตารางข้อมูล (Tables) ต่อไปนี้จะถูกสร้างขึ้นอัตโนมัติ:
   - `teachers` — ข้อมูลผู้สอน
   - `students` — รายชื่อผู้เรียน
   - `attempts` — บันทึกการทำแบบทดสอบก่อนเรียน/หลังเรียน
   - `progress` — บันทึกความก้าวหน้าการศึกษาแต่ละหน่วย
   - `submissions` — บันทึกการส่งงานปฏิบัติ WebAR
   - `materials` — รายการสื่อการเรียนรู้เพิ่มเติม
   - `results` (View) — หน้าสรุปผลคะแนนและค่า Normalized Gain ($g$)

### ขั้นตอนที่ 2: การแต่งตั้งสิทธิ์ผู้สอน (Teacher Account)

1. ไปที่เมนู **Authentication** -> **Users** ใน Supabase Dashboard แล้วสร้างบัญชีผู้สอน (หรือให้ผู้สอนลงทะเบียนผ่านอีเมล)
2. คัดลอก **User UID** ของบัญชีผู้สอน
3. ไปที่ **SQL Editor** แล้วรันคำสั่ง:
   ```sql
   INSERT INTO public.teachers (user_id) VALUES ('<ใส่_USER_UID_ของผู้สอน>') ON CONFLICT DO NOTHING;
   ```

### ขั้นตอนที่ 3: การเพิ่มรายชื่อนักเรียน (Import Student List)

1. ไปที่เมนู **Table Editor** -> เลือกตาราง `students`
2. กดปุ่ม **Insert** -> **Import data from CSV**
3. เตรียมไฟล์ CSV ที่มีโครงสร้างคอลัมน์ดังนี้:
   `id` (รหัสนักเรียน 11 หลัก), `title`, `first_name`, `last_name`, `section`

### ขั้นตอนที่ 4: การเชื่อมต่อ `courseware.html` กับ Supabase

1. เปิดไฟล์ `courseware.html` ด้วย Code Editor (เช่น VS Code)
2. ค้นหาตัวแปรการตั้งค่าต้นไฟล์ JavaScript (บรรทัดที่ประมาณ 340):
   ```javascript
   const SUPABASE_URL = "YOUR_SUPABASE_URL";
   const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
   ```
3. นำค่า **Project URL** และ **API Key (anon/public)** จาก Supabase Dashboard (`Project Settings` -> `API`) มาแทนที่ในตัวแปรทั้งสอง

---

## 🔑 ระบบสิทธิ์และการทำงาน (Features & Capabilities)

### 1. สำหรับผู้เรียน (Student Role)
- **ระบบยืนยันตัวตน:** เข้าสู่ระบบด้วยรหัสนักเรียน 11 หลัก และรหัสผ่าน
- **รูปโปรไฟล์:** รองรับการอัปโหลดรูปโปรไฟล์ ซึ่งจะถูกย่อขนาด (Canvas Compression) ไม่เกิน 400x400px และจัดเก็บอย่างปลอดภัย
- **แบบทดสอบคู่ขนาน (Parallel Tests):**
  - สุ่มชุดข้อสอบ A/B ตามเลขท้ายรหัสนักเรียน (เลขคู่/เลขคี่) เพื่อป้องกันการทุจริต
  - แสดงเฉลยพร้อมคำอธิบายเหตุผลหลังทำแบบทดสอบหลังเรียนสำเร็จ
- **การเรียนรู้แบบปลดล็อก (Linear Progress):** ต้องตอบคำถามแทรกท้ายหน่วยเรียนรู้ได้ถูกต้อง จึงจะปลดล็อกหน่วยถัดไปได้
- **โหมดปฏิบัติการ WebAR (Unit 4):**
  - แสดงผลโมเดล 3D แบบโต้ตอบด้วย `<model-viewer>` v3.4.0
  - ฟอร์มส่งงานรองรับทั้งการส่ง URL WebAR และการอัปโหลดไฟล์หลักฐาน (PNG, JPG, PDF, MP4 &le; 20MB)
- **สรุปผลการเรียน:** แสดงคะแนนก่อนเรียน หลังเรียน และคำนวณอัตราพัฒนาการเรียนรู้ **Normalized Gain ($g$)** ตามแนวคิดของ Hake (1998):
  $$g = \frac{\text{PostTest} - \text{PreTest}}{\text{FullScore} - \text{PreTest}}$$

### 2. สำหรับผู้สอน (Teacher Role)
- **Dashboard ควบคุมการเรียน:** ดูตารางสรุปผลคะแนนและความก้าวหน้ารายบุคคลได้แบบ Real-time
- **ระบบตรวจและให้คะแนน:** ตรวจชิ้นงาน WebAR, ให้คะแนน (0-100), และเขียนข้อเสนอแนะรายบุคคล
- **คลังสื่อการเรียนรู้:** เพิ่ม/ลบ สื่อประกอบการสอน (ไฟล์เอกสาร PDF/Docx/PPTX, ลิงก์ภายนอก, คลิปวิดีโอ)
- **การส่งออกรายงาน (Export CSV):** ส่งออกรายงานคะแนนรวมของนักเรียนทุกคนเป็นไฟล์ `.csv` รองรับภาษาไทยใน Microsoft Excel (UTF-8 with BOM)

---

## 🛡️ ระบบความปลอดภัยและสถาปัตยกรรม (Security & Architecture)

1. **Row Level Security (RLS):** กำหนดสิทธิ์ใหันักเรียนเข้าถึงเฉพาะข้อมูลตนเอง ขณะที่ผู้สอนสามารถอ่านและตรวจงานของนักเรียนทุกคนในระบบได้
2. **Database Triggers:**
   - `handle_new_user`: ตรวจสอบรหัสนักเรียน 11 หลักจากรูปแบบอีเมลก่อนอนุญาตให้ลงทะเบียน
   - `prevent_student_grading_tamper`: ป้องกันไม่ให้นักเรียนแอบแก้ไขคะแนนหรือข้อเสนอแนะของผู้สอน
3. **Private Storage Buckets:** รูปภาพโปรไฟล์ (`photos`), งานปฏิบัติ (`submissions`), และสื่อการเรียนรู้ (`materials`) ถูกจัดเก็บใน Private Buckets และเข้าถึงผ่าน Signed URLs ที่มีอายุจำกัด

---

## 🛠️ เทคโนโลยีที่ใช้ (Tech Stack)

- **Frontend:** HTML5, Tailwind CSS (via CDN), Vanilla JavaScript (ES6+)
- **3D & AR Rendering:** Google `<model-viewer>` v3.4.0 Web Component
- **Backend Services:** Supabase Database (PostgreSQL), Supabase Auth, Supabase Storage
- **Mathematics Notation:** KaTeX / LaTeX Syntax support