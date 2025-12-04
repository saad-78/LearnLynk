-- =====================================================
-- LEARNLYNK RLS POLICIES (CORRECTED)
-- Task 2: Row-Level Security
-- =====================================================

-- =====================================================
-- SUPPORTING TABLES (Required for RLS logic)
-- =====================================================

-- Users table (simplified - normally from auth.users)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'counselor')),
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Teams table
CREATE TABLE IF NOT EXISTS teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User-to-Team mapping (many-to-many)
CREATE TABLE IF NOT EXISTS user_teams (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, team_id)
);

-- Indexes for RLS performance
CREATE INDEX IF NOT EXISTS idx_users_tenant ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_teams_tenant ON teams(tenant_id);
CREATE INDEX IF NOT EXISTS idx_user_teams_user ON user_teams(user_id);
CREATE INDEX IF NOT EXISTS idx_user_teams_team ON user_teams(team_id);

-- =====================================================
-- ENABLE RLS ON ALL TABLES
-- =====================================================
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_teams ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- RLS POLICY: leads - SELECT
-- Logic:
-- 1. Must be in same tenant (critical security boundary)
-- 2. Admins can see all leads in their tenant
-- 3. Counselors can see:
--    a. Leads they own directly
--    b. Leads owned by anyone on their team(s)
-- =====================================================
CREATE POLICY "leads_select_policy"
ON leads
FOR SELECT
USING (
  -- Tenant isolation (ALWAYS first for performance + security)
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    -- CASE 1: User is an admin → see all leads in tenant
    (auth.jwt() ->> 'role') = 'admin'
    
    OR
    
    -- CASE 2: User owns this lead directly
    owner_id = auth.uid()
    
    OR
    
    -- CASE 3: User is on same team as the lead owner
    -- Using EXISTS for performance (faster than IN with subqueries)
    EXISTS (
      SELECT 1 
      FROM user_teams ut1
      INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
      WHERE ut1.user_id = auth.uid()        -- Current user's teams
        AND ut2.user_id = leads.owner_id    -- Lead owner's teams
    )
  )
);

-- =====================================================
-- RLS POLICY: leads - INSERT
-- Logic:
-- 1. Must insert with same tenant_id as current user
-- 2. Only admins and counselors can insert leads
-- =====================================================
CREATE POLICY "leads_insert_policy"
ON leads
FOR INSERT
WITH CHECK (
  -- Security: Force tenant_id to match JWT claim
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  
  AND
  
  -- Only authenticated users with proper roles
  (auth.jwt() ->> 'role') IN ('admin', 'counselor')
);

-- =====================================================
-- RLS POLICY: leads - UPDATE
-- Same visibility rules as SELECT
-- =====================================================
CREATE POLICY "leads_update_policy"
ON leads
FOR UPDATE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    (auth.jwt() ->> 'role') = 'admin'
    OR owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM user_teams ut1
      INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
      WHERE ut1.user_id = auth.uid()
        AND ut2.user_id = leads.owner_id
    )
  )
)
WITH CHECK (
  -- Prevent changing tenant_id to another tenant
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
);

-- =====================================================
-- RLS POLICY: leads - DELETE
-- Only admins can delete leads
-- =====================================================
CREATE POLICY "leads_delete_policy"
ON leads
FOR DELETE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (auth.jwt() ->> 'role') = 'admin'
);

-- =====================================================
-- RLS POLICY: applications - SELECT
-- Inherited access: Can see application if you can see the parent lead
-- =====================================================
CREATE POLICY "applications_select_policy"
ON applications
FOR SELECT
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    (auth.jwt() ->> 'role') = 'admin'
    OR EXISTS (
      SELECT 1 FROM leads
      WHERE leads.id = applications.lead_id
        AND (
          leads.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 
            FROM user_teams ut1
            INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
            WHERE ut1.user_id = auth.uid()
              AND ut2.user_id = leads.owner_id
          )
        )
    )
  )
);

-- =====================================================
-- RLS POLICY: applications - INSERT/UPDATE/DELETE
-- Same access rules as parent lead
-- =====================================================
CREATE POLICY "applications_insert_policy"
ON applications
FOR INSERT
WITH CHECK (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (auth.jwt() ->> 'role') IN ('admin', 'counselor')
);

CREATE POLICY "applications_modify_policy"
ON applications
FOR UPDATE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    (auth.jwt() ->> 'role') = 'admin'
    OR EXISTS (
      SELECT 1 FROM leads
      WHERE leads.id = applications.lead_id
        AND leads.owner_id = auth.uid()
    )
  )
);

CREATE POLICY "applications_delete_policy"
ON applications
FOR DELETE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (auth.jwt() ->> 'role') = 'admin'
);

-- =====================================================
-- RLS POLICY: tasks - SELECT
-- Can see task if you can see the parent application
-- =====================================================
CREATE POLICY "tasks_select_policy"
ON tasks
FOR SELECT
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    (auth.jwt() ->> 'role') = 'admin'
    OR assigned_to = auth.uid()  -- Can see tasks assigned to you
    OR EXISTS (
      SELECT 1 FROM applications
      INNER JOIN leads ON applications.lead_id = leads.id
      WHERE applications.id = tasks.application_id
        AND (
          leads.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 
            FROM user_teams ut1
            INNER JOIN user_teams ut2 ON ut1.team_id = ut2.team_id
            WHERE ut1.user_id = auth.uid()
              AND ut2.user_id = leads.owner_id
          )
        )
    )
  )
);

-- =====================================================
-- RLS POLICY: tasks - INSERT/UPDATE/DELETE
-- =====================================================
CREATE POLICY "tasks_insert_policy"
ON tasks
FOR INSERT
WITH CHECK (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (auth.jwt() ->> 'role') IN ('admin', 'counselor')
);

CREATE POLICY "tasks_update_policy"
ON tasks
FOR UPDATE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    (auth.jwt() ->> 'role') = 'admin'
    OR assigned_to = auth.uid()
  )
);

CREATE POLICY "tasks_delete_policy"
ON tasks
FOR DELETE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (auth.jwt() ->> 'role') = 'admin'
);

-- =====================================================
-- RLS POLICY: users - Basic tenant isolation
-- =====================================================
CREATE POLICY "users_select_policy"
ON users
FOR SELECT
USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);

-- =====================================================
-- RLS POLICY: teams - Basic tenant isolation
-- =====================================================
CREATE POLICY "teams_select_policy"
ON teams
FOR SELECT
USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);

-- =====================================================
-- RLS POLICY: user_teams - Can see your own memberships
-- =====================================================
CREATE POLICY "user_teams_select_policy"
ON user_teams
FOR SELECT
USING (
  user_id = auth.uid()
  OR (auth.jwt() ->> 'role') = 'admin'
);

-- =====================================================
-- COMMENTS: Policy documentation
-- =====================================================
COMMENT ON POLICY "leads_select_policy" ON leads IS 
'Admins see all tenant leads. Counselors see owned leads + team leads via user_teams join.';

COMMENT ON POLICY "applications_select_policy" ON applications IS 
'Inherit access from parent lead. Uses EXISTS subquery to check lead visibility.';

COMMENT ON POLICY "tasks_select_policy" ON tasks IS 
'See tasks if: admin, assigned to you, or can see parent application.';

-- =====================================================
-- END OF RLS POLICIES
-- =====================================================
