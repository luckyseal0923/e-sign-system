import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'https://kkbapnzkfceimviwfibu.supabase.co';
const SUPABASE_KEY = 'sb_publishable_GPvoB2TabnfNl-alQDGHfw_FOewTVzK';

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
