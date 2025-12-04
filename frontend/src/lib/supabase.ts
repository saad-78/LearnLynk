import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// TypeScript types for our data
export interface Task {
  id: string
  application_id: string
  type: 'call' | 'email' | 'review'
  title: string
  description: string | null
  status: string
  due_at: string
  created_at: string
  updated_at: string
}
