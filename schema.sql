-- ==============================================================================
-- SMART KIRANA KHATA - SUPABASE ENTERPRISE DATABASE SCHEMA & RLS POLICIES
-- Target: Supabase PostgreSQL (Version 15+)
-- Commercial Production Grade with Atomic Transaction and Loyalty Functions
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. CORE TABLE DEFINITIONS
-- ==============================================================================

-- 2.1 SHOPS (Commercial shop profiles)
CREATE TABLE IF NOT EXISTS public.shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL DEFAULT 'My Kirana Store',
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    phone TEXT,
    address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.2 SHOPKEEPERS (Authorized staff & co-owners)
CREATE TABLE IF NOT EXISTS public.shopkeepers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('owner', 'manager', 'staff')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(shop_id, user_id)
);

-- 2.3 FAMILIES (Shared Family Khata Household Accounts)
CREATE TABLE IF NOT EXISTS public.families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
    family_name TEXT NOT NULL,
    primary_phone TEXT,
    address TEXT,
    credit_limit NUMERIC(12,2) DEFAULT 10000.00,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.4 FAMILY MEMBERS (Linked Supabase auth users with head/member roles)
CREATE TABLE IF NOT EXISTS public.family_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    member_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('head', 'member')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'invited', 'revoked')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(family_id, user_id)
);

-- 2.5 CUSTOMERS (Preserves existing table & backwards compatibility)
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone TEXT,
    owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Add upgraded columns if they don't already exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='customers' AND column_name='shop_id') THEN
        ALTER TABLE public.customers ADD COLUMN shop_id UUID REFERENCES public.shops(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='customers' AND column_name='family_id') THEN
        ALTER TABLE public.customers ADD COLUMN family_id UUID REFERENCES public.families(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='customers' AND column_name='credit_limit') THEN
        ALTER TABLE public.customers ADD COLUMN credit_limit NUMERIC(12,2) DEFAULT 5000.00;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='customers' AND column_name='is_active') THEN
        ALTER TABLE public.customers ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='customers' AND column_name='notes') THEN
        ALTER TABLE public.customers ADD COLUMN notes TEXT;
    END IF;
END $$;

-- 2.6 TRANSACTIONS (Preserves existing purchases and payments)
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('purchase', 'payment')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='transactions' AND column_name='created_by') THEN
        ALTER TABLE public.transactions ADD COLUMN created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 2.7 LOYALTY REDEMPTIONS (Preserves points redemption history)
CREATE TABLE IF NOT EXISTS public.loyalty_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    points_used INTEGER NOT NULL CHECK (points_used > 0),
    discount_amount NUMERIC(12,2) NOT NULL CHECK (discount_amount > 0),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='loyalty_redemptions' AND column_name='created_by') THEN
        ALTER TABLE public.loyalty_redemptions ADD COLUMN created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 2.8 PAYMENT REMINDERS (Informational notices for customers & shopkeeper)
CREATE TABLE IF NOT EXISTS public.payment_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    amount_due NUMERIC(12,2) NOT NULL,
    due_date DATE,
    message TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'cleared', 'acknowledged')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.9 AUDIT LOGS (Immutable security and accounting history)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES public.shops(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.10 BIOMETRIC CREDENTIALS (WebAuthn / FIDO2 and Local Scanner References)
CREATE TABLE IF NOT EXISTS public.biometric_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    credential_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    counter BIGINT DEFAULT 0,
    device_name TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==============================================================================
-- 3. INDEXES FOR PERFORMANCE
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_customers_owner ON public.customers(owner_id);
CREATE INDEX IF NOT EXISTS idx_customers_family ON public.customers(family_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON public.customers(phone);
CREATE INDEX IF NOT EXISTS idx_transactions_customer ON public.transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_redemptions_customer ON public.loyalty_redemptions(customer_id);
CREATE INDEX IF NOT EXISTS idx_family_members_user ON public.family_members(user_id);
CREATE INDEX IF NOT EXISTS idx_family_members_family ON public.family_members(family_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_shop ON public.audit_logs(shop_id);

-- ==============================================================================
-- 4. DETERMINISTIC HELPER FUNCTIONS
-- ==============================================================================

-- 4.1 Check if user is shopkeeper
CREATE OR REPLACE FUNCTION public.is_shopkeeper(check_uid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.shops WHERE owner_id = check_uid
        UNION
        SELECT 1 FROM public.shopkeepers WHERE user_id = check_uid
        UNION
        SELECT 1 FROM public.customers WHERE owner_id = check_uid
    );
$$;

-- 4.2 Determine authenticated user role
CREATE OR REPLACE FUNCTION public.get_user_role(check_uid UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.shops WHERE owner_id = check_uid) OR
       EXISTS (SELECT 1 FROM public.shopkeepers WHERE user_id = check_uid) OR
       EXISTS (SELECT 1 FROM public.customers WHERE owner_id = check_uid) THEN
        RETURN 'shopkeeper';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.family_members 
        WHERE user_id = check_uid AND status = 'active'
    ) THEN
        RETURN 'customer';
    END IF;

    RETURN 'unassigned';
END;
$$;

-- 4.3 Get customer outstanding balance
CREATE OR REPLACE FUNCTION public.get_customer_balance(cust_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    total_purchases NUMERIC := 0;
    total_payments NUMERIC := 0;
    total_discounts NUMERIC := 0;
    ledger_due NUMERIC := 0;
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO total_purchases
    FROM public.transactions
    WHERE customer_id = cust_id AND type = 'purchase';

    SELECT COALESCE(SUM(amount), 0) INTO total_payments
    FROM public.transactions
    WHERE customer_id = cust_id AND type = 'payment';

    SELECT COALESCE(SUM(discount_amount), 0) INTO total_discounts
    FROM public.loyalty_redemptions
    WHERE customer_id = cust_id;

    ledger_due := (total_purchases - total_payments) - total_discounts;
    IF ledger_due < 0 THEN
        ledger_due := 0;
    END IF;

    RETURN ledger_due;
END;
$$;

-- 4.4 Get customer available loyalty points
CREATE OR REPLACE FUNCTION public.get_customer_points(cust_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    total_eligible_purchases NUMERIC := 0;
    earned_pts INTEGER := 0;
    used_pts INTEGER := 0;
    available_pts INTEGER := 0;
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO total_eligible_purchases
    FROM public.transactions
    WHERE customer_id = cust_id AND type = 'purchase';

    SELECT COALESCE(SUM(points_used), 0) INTO used_pts
    FROM public.loyalty_redemptions
    WHERE customer_id = cust_id;

    earned_pts := FLOOR(total_eligible_purchases / 100);
    available_pts := earned_pts - used_pts;

    IF available_pts < 0 THEN
        available_pts := 0;
    END IF;

    RETURN available_pts;
END;
$$;

-- ==============================================================================
-- 5. ATOMIC SECURE TRANSACTION & LOYALTY RPC FUNCTIONS
-- ==============================================================================

-- 5.1 ATOMIC TRANSACTION ENTRY (Validates payment cannot exceed outstanding due)
CREATE OR REPLACE FUNCTION public.record_transaction_secure(
    p_customer_id UUID,
    p_type TEXT,
    p_amount NUMERIC,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_owner_id UUID;
    v_current_due NUMERIC;
    v_inserted_id UUID;
    v_new_due NUMERIC;
BEGIN
    -- 1. Check customer exists and belongs to current user
    SELECT owner_id INTO v_owner_id FROM public.customers WHERE id = p_customer_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer not found.';
    END IF;

    IF v_owner_id IS NOT NULL AND v_owner_id <> auth.uid() THEN
        -- Check if staff
        IF NOT EXISTS (
            SELECT 1 FROM public.shopkeepers sk
            JOIN public.shops s ON s.id = sk.shop_id
            WHERE s.owner_id = v_owner_id AND sk.user_id = auth.uid()
        ) THEN
            RAISE EXCEPTION 'Unauthorized: You do not have permission to manage this customer.';
        END IF;
    END IF;

    -- 2. Validate amount
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero.';
    END IF;

    IF p_type NOT IN ('purchase', 'payment') THEN
        RAISE EXCEPTION 'Invalid transaction type: %', p_type;
    END IF;

    -- 3. Validate payment against current balance
    v_current_due := public.get_customer_balance(p_customer_id);
    IF p_type = 'payment' AND p_amount > v_current_due THEN
        RAISE EXCEPTION 'Payment of ₹% exceeds current outstanding balance of ₹%.', p_amount, v_current_due;
    END IF;

    -- 4. Insert transaction
    INSERT INTO public.transactions (customer_id, type, amount, note, created_by)
    VALUES (p_customer_id, p_type, p_amount, p_note, auth.uid())
    RETURNING id INTO v_inserted_id;

    -- 5. Compute new due
    v_new_due := public.get_customer_balance(p_customer_id);

    -- 6. Log audit entry
    INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id, details)
    VALUES (
        auth.uid(),
        'TRANSACTION_' || UPPER(p_type),
        'transactions',
        v_inserted_id::text,
        jsonb_build_object(
            'customer_id', p_customer_id,
            'amount', p_amount,
            'note', p_note,
            'previous_due', v_current_due,
            'new_due', v_new_due
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_inserted_id,
        'new_balance', v_new_due,
        'available_points', public.get_customer_points(p_customer_id)
    );
END;
$$;

-- 5.2 ATOMIC LOYALTY REDEMPTION (Prevents double spending & balance overdraft)
CREATE OR REPLACE FUNCTION public.redeem_loyalty_points_secure(
    p_customer_id UUID,
    p_points_used INTEGER,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_owner_id UUID;
    v_available_points INTEGER;
    v_current_due NUMERIC;
    v_discount_amount NUMERIC;
    v_redemption_id UUID;
    v_new_due NUMERIC;
    v_remaining_points INTEGER;
BEGIN
    -- 1. Check customer exists and belongs to current user
    SELECT owner_id INTO v_owner_id FROM public.customers WHERE id = p_customer_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer not found.';
    END IF;

    IF v_owner_id IS NOT NULL AND v_owner_id <> auth.uid() THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.shopkeepers sk
            JOIN public.shops s ON s.id = sk.shop_id
            WHERE s.owner_id = v_owner_id AND sk.user_id = auth.uid()
        ) THEN
            RAISE EXCEPTION 'Unauthorized: You do not have permission to manage this customer.';
        END IF;
    END IF;

    -- 2. Validate points
    IF p_points_used <= 0 THEN
        RAISE EXCEPTION 'Points redeemed must be a positive whole number.';
    END IF;

    v_available_points := public.get_customer_points(p_customer_id);
    IF p_points_used > v_available_points THEN
        RAISE EXCEPTION 'Insufficient points: % requested, but only % available.', p_points_used, v_available_points;
    END IF;

    -- 3. Calculate discount (1 point = ₹2 discount)
    v_discount_amount := p_points_used * 2;
    v_current_due := public.get_customer_balance(p_customer_id);

    IF v_current_due <= 0 THEN
        RAISE EXCEPTION 'Customer has no outstanding balance to apply discount to.';
    END IF;

    IF v_discount_amount > v_current_due THEN
        RAISE EXCEPTION 'Discount amount ₹% cannot exceed current balance of ₹%.', v_discount_amount, v_current_due;
    END IF;

    -- 4. Insert redemption record atomically
    INSERT INTO public.loyalty_redemptions (customer_id, points_used, discount_amount, note, created_by)
    VALUES (p_customer_id, p_points_used, v_discount_amount, p_note, auth.uid())
    RETURNING id INTO v_redemption_id;

    -- 5. Calculate new state
    v_new_due := public.get_customer_balance(p_customer_id);
    v_remaining_points := public.get_customer_points(p_customer_id);

    -- 6. Audit log
    INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id, details)
    VALUES (
        auth.uid(),
        'LOYALTY_REDEMPTION',
        'loyalty_redemptions',
        v_redemption_id::text,
        jsonb_build_object(
            'customer_id', p_customer_id,
            'points_used', p_points_used,
            'discount_amount', v_discount_amount,
            'previous_due', v_current_due,
            'new_due', v_new_due,
            'remaining_points', v_remaining_points
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'redemption_id', v_redemption_id,
        'discount_amount', v_discount_amount,
        'new_balance', v_new_due,
        'remaining_points', v_remaining_points
    );
END;
$$;

-- ==============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

-- Enable RLS on all tables
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shopkeepers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biometric_credentials ENABLE ROW LEVEL SECURITY;

-- 6.1 SHOPS POLICIES
DROP POLICY IF EXISTS "Shops owner manage" ON public.shops;
CREATE POLICY "Shops owner manage" ON public.shops
    FOR ALL
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Shops customer view" ON public.shops;
CREATE POLICY "Shops customer view" ON public.shops
    FOR SELECT
    USING (
        id IN (
            SELECT f.shop_id FROM public.families f
            JOIN public.family_members fm ON fm.family_id = f.id
            WHERE fm.user_id = auth.uid() AND fm.status = 'active'
        )
    );

-- 6.2 FAMILIES POLICIES
DROP POLICY IF EXISTS "Shopkeeper manage families" ON public.families;
CREATE POLICY "Shopkeeper manage families" ON public.families
    FOR ALL
    USING (
        shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid())
        OR shop_id IS NULL
    )
    WITH CHECK (
        shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid())
        OR shop_id IS NULL
    );

DROP POLICY IF EXISTS "Family members view family" ON public.families;
CREATE POLICY "Family members view family" ON public.families
    FOR SELECT
    USING (
        id IN (
            SELECT family_id FROM public.family_members
            WHERE user_id = auth.uid() AND status = 'active'
        )
    );

-- 6.3 FAMILY MEMBERS POLICIES
DROP POLICY IF EXISTS "Shopkeeper manage family members" ON public.family_members;
CREATE POLICY "Shopkeeper manage family members" ON public.family_members
    FOR ALL
    USING (
        family_id IN (
            SELECT f.id FROM public.families f
            JOIN public.shops s ON s.id = f.shop_id
            WHERE s.owner_id = auth.uid()
        )
    )
    WITH CHECK (
        family_id IN (
            SELECT f.id FROM public.families f
            JOIN public.shops s ON s.id = f.shop_id
            WHERE s.owner_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Family member view members" ON public.family_members;
CREATE POLICY "Family member view members" ON public.family_members
    FOR SELECT
    USING (
        family_id IN (
            SELECT family_id FROM public.family_members
            WHERE user_id = auth.uid() AND status = 'active'
        )
    );

-- 6.4 CUSTOMERS POLICIES
DROP POLICY IF EXISTS "Shopkeeper manage customers" ON public.customers;
CREATE POLICY "Shopkeeper manage customers" ON public.customers
    FOR ALL
    USING (
        owner_id = auth.uid()
        OR shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid())
    )
    WITH CHECK (
        owner_id = auth.uid()
        OR shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid())
    );

DROP POLICY IF EXISTS "Family member view customer khata" ON public.customers;
CREATE POLICY "Family member view customer khata" ON public.customers
    FOR SELECT
    USING (
        family_id IN (
            SELECT family_id FROM public.family_members
            WHERE user_id = auth.uid() AND status = 'active'
        )
    );

-- 6.5 TRANSACTIONS POLICIES
DROP POLICY IF EXISTS "Shopkeeper manage transactions" ON public.transactions;
CREATE POLICY "Shopkeeper manage transactions" ON public.transactions
    FOR ALL
    USING (
        customer_id IN (
            SELECT id FROM public.customers
            WHERE owner_id = auth.uid()
               OR shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid())
        )
    )
    WITH CHECK (
        customer_id IN (
            SELECT id FROM public.customers
            WHERE owner_id = auth.uid()
               OR shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Family member view transactions" ON public.transactions;
CREATE POLICY "Family member view transactions" ON public.transactions
    FOR SELECT
    USING (
        customer_id IN (
            SELECT c.id FROM public.customers c
            JOIN public.family_members fm ON fm.family_id = c.family_id
            WHERE fm.user_id = auth.uid() AND fm.status = 'active'
        )
    );

-- 6.6 LOYALTY REDEMPTIONS POLICIES
DROP POLICY IF EXISTS "Shopkeeper manage redemptions" ON public.loyalty_redemptions;
CREATE POLICY "Shopkeeper manage redemptions" ON public.loyalty_redemptions
    FOR ALL
    USING (
        customer_id IN (
            SELECT id FROM public.customers
            WHERE owner_id = auth.uid()
               OR shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid())
        )
    )
    WITH CHECK (
        customer_id IN (
            SELECT id FROM public.customers
            WHERE owner_id = auth.uid()
               OR shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Family member view redemptions" ON public.loyalty_redemptions;
CREATE POLICY "Family member view redemptions" ON public.loyalty_redemptions
    FOR SELECT
    USING (
        customer_id IN (
            SELECT c.id FROM public.customers c
            JOIN public.family_members fm ON fm.family_id = c.family_id
            WHERE fm.user_id = auth.uid() AND fm.status = 'active'
        )
    );

-- 6.7 PAYMENT REMINDERS POLICIES
DROP POLICY IF EXISTS "Shopkeeper manage reminders" ON public.payment_reminders;
CREATE POLICY "Shopkeeper manage reminders" ON public.payment_reminders
    FOR ALL
    USING (
        customer_id IN (
            SELECT id FROM public.customers
            WHERE owner_id = auth.uid()
        )
    )
    WITH CHECK (
        customer_id IN (
            SELECT id FROM public.customers
            WHERE owner_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Family member view reminders" ON public.payment_reminders;
CREATE POLICY "Family member view reminders" ON public.payment_reminders
    FOR SELECT
    USING (
        customer_id IN (
            SELECT c.id FROM public.customers c
            JOIN public.family_members fm ON fm.family_id = c.family_id
            WHERE fm.user_id = auth.uid() AND fm.status = 'active'
        )
    );

-- 6.8 AUDIT LOGS POLICIES
DROP POLICY IF EXISTS "Shopkeeper view audit logs" ON public.audit_logs;
CREATE POLICY "Shopkeeper view audit logs" ON public.audit_logs
    FOR SELECT
    USING (
        user_id = auth.uid()
        OR shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid())
    );

-- 6.9 BIOMETRIC CREDENTIALS POLICIES
DROP POLICY IF EXISTS "User manage own biometrics" ON public.biometric_credentials;
CREATE POLICY "User manage own biometrics" ON public.biometric_credentials
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ==============================================================================
-- 7. AUTOMATION TRIGGERS
-- ==============================================================================

-- 7.1 Auto-link default shop and family for every new customer if not set
CREATE OR REPLACE FUNCTION public.trg_customer_init()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_family_id UUID;
BEGIN
    -- Set owner_id to current auth user if null
    IF NEW.owner_id IS NULL THEN
        NEW.owner_id := auth.uid();
    END IF;

    -- Ensure a default shop exists for this owner
    IF NEW.owner_id IS NOT NULL THEN
        SELECT id INTO v_shop_id FROM public.shops WHERE owner_id = NEW.owner_id LIMIT 1;
        IF v_shop_id IS NULL THEN
            INSERT INTO public.shops (name, owner_id)
            VALUES ('My Kirana Store', NEW.owner_id)
            RETURNING id INTO v_shop_id;
        END IF;
        IF NEW.shop_id IS NULL THEN
            NEW.shop_id := v_shop_id;
        END IF;
    END IF;

    -- Create linked family khata if customer does not have one
    IF NEW.family_id IS NULL THEN
        INSERT INTO public.families (shop_id, family_name, primary_phone)
        VALUES (NEW.shop_id, NEW.name || ' Family Khata', NEW.phone)
        RETURNING id INTO v_family_id;

        NEW.family_id := v_family_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_customer_init_before ON public.customers;
CREATE TRIGGER trg_customer_init_before
    BEFORE INSERT ON public.customers
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_customer_init();
