-- ============================================================

-- ------------------------------------------------------------
-- 0. REFERENCE TABLES FILE  
--
-- Create reference tables that will help with analysis down 
-- the road, and in a separate file that can be easily re-run
-- instead of going through the expensive files again. 

-- ------------------------------------------------------------


-- Region table: Classify the states for the loans into regions
-- defined by the US Census Bureau

DROP TABLE IF EXISTS state_region CASCADE;

CREATE TABLE state_region (
    property_state      varchar(2) PRIMARY KEY,
    state_name          text NOT NULL,
    census_division     text NOT NULL,
    census_region       text NOT NULL,
    judicial            boolean         -- NULL where ambiguous

);
-- judicial: customary process, not a legal absolute. Most states
-- permit both, here I try to list the most common process using
-- data from <https://www.nolo.com/legal-encyclopedia/chart-judicial-v-nonjudicial-foreclosures.html>

INSERT INTO state_region (property_state, state_name, census_division, census_region, judicial) VALUES
    ('AK','Alaska','Pacific','West',false),
    ('AL','Alabama','East South Central','South',false),
    ('AR','Arkansas','West South Central','South',false),
    ('AZ','Arizona','Mountain','West',false),
    ('CA','California','Pacific','West',false),
    ('CO','Colorado','Mountain','West',false),
    ('CT','Connecticut','New England','Northeast',true),
    ('DC','District of Columbia','South Atlantic','South',true),
    ('DE','Delaware','South Atlantic','South',true),
    ('FL','Florida','South Atlantic','South',true),
    ('GA','Georgia','South Atlantic','South',false),
    ('GU','Guam','Pacific','West',null),
    ('HI','Hawaii','Pacific','West',true),
    ('IA','Iowa','West North Central','Midwest',true),
    ('ID','Idaho','Mountain','West',false),
    ('IL','Illinois','East North Central','Midwest',true),
    ('IN','Indiana','East North Central','Midwest',true),
    ('KS','Kansas','West North Central','Midwest',true),
    ('KY','Kentucky','East South Central','South',true),
    ('LA','Louisiana','West South Central','South',true),
    ('MA','Massachusetts','New England','Northeast',false),
    ('MD','Maryland','South Atlantic','South',false),
    ('ME','Maine','New England','Northeast',true),
    ('MI','Michigan','East North Central','Midwest',false),
    ('MN','Minnesota','West North Central','Midwest',false),
    ('MO','Missouri','West North Central','Midwest',false),
    ('MS','Mississippi','East South Central','South',false),
    ('MT','Montana','Mountain','West',false),
    ('NC','North Carolina','South Atlantic','South',false),
    ('ND','North Dakota','West North Central','Midwest',true),
    ('NE','Nebraska','West North Central','Midwest',false),
    ('NH','New Hampshire','New England','Northeast',false),
    ('NJ','New Jersey','Middle Atlantic','Northeast',true),
    ('NM','New Mexico','Mountain','West',true),
    ('NV','Nevada','Mountain','West',false),
    ('NY','New York','Middle Atlantic','Northeast',true),
    ('OH','Ohio','East North Central','Midwest',true),
    ('OK','Oklahoma','West South Central','South',true),
    ('OR','Oregon','Pacific','West',false),
    ('PA','Pennsylvania','Middle Atlantic','Northeast',true),
    ('PR','Puerto Rico','South Atlantic','South',null),
    ('RI','Rhode Island','New England','Northeast',false),
    ('SC','South Carolina','South Atlantic','South',true),
    ('SD','South Dakota','West North Central','Midwest',false),
    ('TN','Tennessee','East South Central','South',false),
    ('TX','Texas','West South Central','South',false),
    ('UT','Utah','Mountain','West',false),
    ('VA','Virginia','South Atlantic','South',false),
    ('VI','Virgin Islands','South Atlantic','South',false),
    ('VT','Vermont','New England','Northeast',true),
    ('WA','Washington','Pacific','West',false),
    ('WI','Wisconsin','East North Central','Midwest',true),
    ('WV','West Virginia','South Atlantic','South',false),
    ('WY','Wyoming','Mountain','West',false);


CREATE TABLE pmms (
    period_ym   integer PRIMARY KEY,
    rate_30yr   numeric(6,3)
);