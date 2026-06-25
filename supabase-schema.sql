-- ==========================================
-- E-Sign 遠端簽名系統 - Supabase 資料庫設定腳本
-- ==========================================
-- 請在 Supabase Dashboard -> SQL Editor 中執行此腳本

-- 1. 建立主案件資料表 (cases)
CREATE TABLE IF NOT EXISTS public.cases (
    case_id text PRIMARY KEY,
    case_name text NOT NULL,
    applicant_name text NOT NULL,
    birth_date text NOT NULL,
    staff_id text NOT NULL,
    password text NOT NULL,
    applicant_email text,
    sign_count integer NOT NULL,
    file_name text NOT NULL,
    pdf_path text,
    status text NOT NULL DEFAULT '已建立',
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. 建立欄位配置資料表 (fields)
CREATE TABLE IF NOT EXISTS public.fields (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id text REFERENCES public.cases(case_id) ON DELETE CASCADE NOT NULL,
    type text NOT NULL, -- 'prefill' (預填), 'sig' (簽章), 'txt' (簽署人輸入)
    page integer NOT NULL,
    x_ratio double precision NOT NULL,
    y_ratio double precision NOT NULL,
    w_ratio double precision NOT NULL,
    h_ratio double precision NOT NULL,
    content text,
    style jsonb
);

-- 3. 建立子任務簽署人資料表 (child_tasks)
CREATE TABLE IF NOT EXISTS public.child_tasks (
    sign_id text PRIMARY KEY,
    case_id text REFERENCES public.cases(case_id) ON DELETE CASCADE NOT NULL,
    seq integer NOT NULL,
    signer_name text NOT NULL,
    status text NOT NULL DEFAULT '待簽署', -- '待簽署', '簽署完成'
    signed_at timestamp with time zone,
    signature_path text,
    text_inputs jsonb, -- 儲存簽署人自己輸入的文字內容，例如 {"field-uuid": "值"}
    access_token uuid UNIQUE DEFAULT gen_random_uuid() NOT NULL
);

-- 4. 停用資料表 RLS 以利快速 Demo/測試 (若正式上線建議啟用並設定對應 Policy)
ALTER TABLE public.cases DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.fields DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.child_tasks DISABLE ROW LEVEL SECURITY;

-- 5. 自動初始化 Storage Buckets (若 buckets 已存在則忽略)
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('pdfs', 'pdfs', true),
    ('signatures', 'signatures', true)
ON CONFLICT (id) DO NOTHING;

-- 6. 開啟 Storage Buckets 的公共讀寫權限政策 (Policies)
-- 先刪除可能存在的同名政策以防衝突
DROP POLICY IF EXISTS "Public Select PDF" ON storage.objects;
DROP POLICY IF EXISTS "Public Insert PDF" ON storage.objects;
DROP POLICY IF EXISTS "Public Update PDF" ON storage.objects;
DROP POLICY IF EXISTS "Public Delete PDF" ON storage.objects;
DROP POLICY IF EXISTS "Public Select Signature" ON storage.objects;
DROP POLICY IF EXISTS "Public Insert Signature" ON storage.objects;
DROP POLICY IF EXISTS "Public Update Signature" ON storage.objects;
DROP POLICY IF EXISTS "Public Delete Signature" ON storage.objects;

-- 建立 PDF 政策
CREATE POLICY "Public Select PDF" ON storage.objects FOR SELECT USING (bucket_id = 'pdfs');
CREATE POLICY "Public Insert PDF" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'pdfs');
CREATE POLICY "Public Update PDF" ON storage.objects FOR UPDATE USING (bucket_id = 'pdfs');
CREATE POLICY "Public Delete PDF" ON storage.objects FOR DELETE USING (bucket_id = 'pdfs');

-- 建立簽章政策
CREATE POLICY "Public Select Signature" ON storage.objects FOR SELECT USING (bucket_id = 'signatures');
CREATE POLICY "Public Insert Signature" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'signatures');
CREATE POLICY "Public Update Signature" ON storage.objects FOR UPDATE USING (bucket_id = 'signatures');
CREATE POLICY "Public Delete Signature" ON storage.objects FOR DELETE USING (bucket_id = 'signatures');

-- 7. 建立員工/管理員帳號資料表 (users)
CREATE TABLE IF NOT EXISTS public.users (
    staff_id text PRIMARY KEY,
    name text NOT NULL,
    birth_date text NOT NULL, -- 格式：YYYYMMDD，例如 '19850923'
    password text NOT NULL,
    role text NOT NULL DEFAULT 'user', -- 'user' (員工) 或 'admin' (系統管理員)
    email text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 停用 users 資料表的 RLS
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- 預設寫入測試資料 (若有衝突則更新)
INSERT INTO public.users (staff_id, name, birth_date, password, role, email)
VALUES 
    ('104114', '測試員工', '19850923', '84384131', 'user', 'user104114@example.com'),
    ('admin01', '系統管理員', '19800101', 'admin888', 'admin', 'admin@example.com')
ON CONFLICT (staff_id) DO UPDATE 
SET name = EXCLUDED.name, 
    birth_date = EXCLUDED.birth_date, 
    password = EXCLUDED.password, 
    role = EXCLUDED.role,
    email = EXCLUDED.email;

