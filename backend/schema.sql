-- =====================================================
-- LEARNLYNK DATABASE SCHEMA
-- Task 1: Supabase Schema Challenge
-- =====================================================

-- Enable UUID extension (though gen_random_uuid() is built-in to modern Postgres)
-- Including this for compatibility with older Supabase instances
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- FUNCTION: Auto-update updated_at timestamp
-- =====================================================
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TABLE: leads
-- =====================================================
CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  
  -- Lead-specific fields
  owner_id UUID NOT NULL,  -- References user who owns this lead
  stage TEXT NOT NULL DEFAULT 'new',  -- e.g., 'new', 'contacted', 'qualified', 'converted'
  
  -- Contact information
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  phone TEXT,
  
  -- Metadata
  source TEXT,  -- e.g., 'website', 'referral', 'ad'
  notes TEXT,
  
  -- Standard timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- TABLE: applications
-- =====================================================
CREATE TABLE applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  
  -- Foreign key to leads
  lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  
  -- Application-specific fields
  status TEXT NOT NULL DEFAULT 'pending',  -- e.g., 'pending', 'reviewing', 'approved', 'rejected'
  program TEXT,  -- Program/course they're applying to
  counselor_id UUID,  -- Assigned counselor
  
  -- Application details
  submitted_at TIMESTAMPTZ,
  reviewed_at TIMESTAMPTZ,
  decision TEXT,
  
  -- Standard timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- TABLE: tasks
-- =====================================================
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  
  -- Foreign key to applications
  application_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
  
  -- Task details
  type TEXT NOT NULL CHECK (type IN ('call', 'email', 'review')),
  title TEXT NOT NULL,
  description TEXT,
  
  -- Assignment and status
  assigned_to UUID,  -- User ID
  status TEXT NOT NULL DEFAULT 'pending',  -- e.g., 'pending', 'in_progress', 'completed', 'cancelled'
  
  -- Scheduling
  due_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  
  -- Constraint: due_at must be after created_at
  CONSTRAINT due_at_after_created CHECK (due_at >= created_at),
  
  -- Standard timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- INDEXES: leads
-- Performance optimization for common query patterns
-- =====================================================

-- Multi-tenant queries always filter by tenant_id first
CREATE INDEX idx_leads_tenant_id ON leads(tenant_id);

-- Fetch leads by owner (counselor dashboard view)
CREATE INDEX idx_leads_tenant_owner ON leads(tenant_id, owner_id);

-- Fetch leads by stage (pipeline views, filtering)
CREATE INDEX idx_leads_tenant_stage ON leads(tenant_id, stage);

-- Sorting/filtering by creation date (recent leads, reports)
CREATE INDEX idx_leads_created_at ON leads(created_at DESC);

-- Email lookups for deduplication
CREATE INDEX idx_leads_email ON leads(email) WHERE email IS NOT NULL;

-- =====================================================
-- INDEXES: applications
-- =====================================================

-- Tenant isolation
CREATE INDEX idx_applications_tenant_id ON applications(tenant_id);

-- Fetch all applications for a specific lead
CREATE INDEX idx_applications_lead_id ON applications(lead_id);

-- Composite index for tenant + lead queries (common in UI)
CREATE INDEX idx_applications_tenant_lead ON applications(tenant_id, lead_id);

-- Status filtering (active applications, pending reviews)
CREATE INDEX idx_applications_tenant_status ON applications(tenant_id, status);

-- =====================================================
-- INDEXES: tasks
-- =====================================================

-- Tenant isolation
CREATE INDEX idx_tasks_tenant_id ON tasks(tenant_id);

-- Fetch tasks for a specific application
CREATE INDEX idx_tasks_application_id ON tasks(application_id);

-- CRITICAL: "Tasks due today" query pattern
-- Partial index excludes completed tasks (smaller, faster)
CREATE INDEX idx_tasks_due_status ON tasks(due_at, status) 
WHERE status != 'completed';

-- Fetch tasks assigned to a specific user
CREATE INDEX idx_tasks_assigned ON tasks(tenant_id, assigned_to, status);

-- Overdue tasks query (due_at < NOW() AND status != completed)
CREATE INDEX idx_tasks_overdue ON tasks(due_at) 
WHERE status NOT IN ('completed', 'cancelled');

-- =====================================================
-- TRIGGERS: Auto-update updated_at on all tables
-- =====================================================

CREATE TRIGGER set_updated_at_leads
  BEFORE UPDATE ON leads
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at_applications
  BEFORE UPDATE ON applications
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at_tasks
  BEFORE UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_updated_at();

-- =====================================================
-- COMMENTS: Documentation for future developers
-- =====================================================

COMMENT ON TABLE leads IS 'Stores potential customer information. One lead can have multiple applications.';
COMMENT ON TABLE applications IS 'Stores formal applications submitted by leads. Each application belongs to one lead.';
COMMENT ON TABLE tasks IS 'Action items related to applications (calls, emails, reviews). Linked to applications via application_id.';

COMMENT ON COLUMN leads.owner_id IS 'User ID of the counselor/agent who owns this lead';
COMMENT ON COLUMN leads.stage IS 'Current position in the sales pipeline';

COMMENT ON COLUMN applications.lead_id IS 'Reference to parent lead. CASCADE deletes applications when lead is deleted.';

COMMENT ON COLUMN tasks.type IS 'Task type: call, email, or review. Enforced by CHECK constraint.';
COMMENT ON COLUMN tasks.due_at IS 'Must be >= created_at (enforced by CHECK constraint)';
COMMENT ON COLUMN tasks.application_id IS 'Reference to parent application. CASCADE deletes tasks when application is deleted.';

-- =====================================================
-- END OF SCHEMA
-- =====================================================
