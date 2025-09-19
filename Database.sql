-- The following block creates the BUILDING table, which stores information about each building, including a unique identifier,
-- associated department name, and a count of people currently inside. The primary key ensures each building_id is unique.

CREATE TABLE IF NOT EXISTS public."BUILDING" (
  building_id text NOT NULL,
  Dept_Name character varying NOT NULL DEFAULT ''::character varying,
  total_count bigint NOT NULL DEFAULT 0,
  CONSTRAINT "BUILDING_pkey" PRIMARY KEY (building_id)
);

-- This block defines the EntryExitLog table to record entry and exit events for buildings. It includes an auto-incrementing tag_id, 
-- the associated building_id, timestamps for entry and exit, and the direction of movement (IN or OUT). A composite primary key is used 
-- for tag_id and building_id.

CREATE TABLE IF NOT EXISTS public."EntryExitLog" (
  tag_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  building_id text NOT NULL DEFAULT ''::text,
  entry_time timestamp without time zone NOT NULL DEFAULT now(),
  exit_time timestamp without time zone,
  direction text,
  CONSTRAINT "EntryExitLog_pkey" PRIMARY KEY (tag_id, building_id)
);

-- Insert sample building data
INSERT INTO public."BUILDING" (building_id, Dept_Name, total_count) VALUES
('A22', 'Drawing Office 2', 0),
('A25', 'Structures Laboratory', 0),
('A28', 'Department of Manufacturing and Industrial Engineering', 0),
('B1', 'Department of Chemical and Process Engineering', 0),
('B2', 'Mathematics/Management/Computing Centre', 0),
('B3', 'Drawing Office 1', 0),
('B4', 'Professor E.O.E. Pereira Theatre', 0),
('B5', 'Administrative Building', 0),
('B6', 'Security Unit', 0),
('C10', 'Electrical and Electronic Workshop', 0),
('C11/C12', 'Surveying/Soil Lab', 0),
('C13', 'Materials Lab', 0),
('C8', 'Department of Electrical and Electronic Engineering', 0),
('C9', 'Department of Computer Engineering', 0),
('D15', 'Fluids Lab', 0),
('D16/D17', 'New/Applied Mechanics Labs', 0),
('D18', 'Thermodynamics Lab', 0),
('D20/D21', 'Engineering Workshop/Engineering Carpentry Shop', 0)
ON CONFLICT (building_id) DO NOTHING;

-- This function, handle_scan_before, manages entry and exit scans before inserting records into EntryExitLog.
-- It updates entry/exit times and building occupancy counts based on the scan direction (IN or OUT), ensuring 
-- accurate tracking and preventing invalid inserts for OUT scans.

CREATE OR REPLACE FUNCTION handle_scan_before()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE NOTICE 'Trigger fired: tag_id=%, building_id=%, direction=%',
    NEW.tag_id, NEW.building_id, NEW.direction;

  IF NEW.direction = 'IN' THEN
    NEW.entry_time := NOW();
    NEW.exit_time := NULL;
    
    UPDATE "BUILDING"
    SET total_count = total_count + 1
    WHERE building_id = NEW.building_id;

    RAISE NOTICE 'IN detected → Processing tag_id=%', NEW.tag_id;
    RETURN NEW;

  ELSIF NEW.direction = 'OUT' THEN
    UPDATE "EntryExitLog"
    SET exit_time = NOW()
    WHERE tag_id = NEW.tag_id;
    
    IF FOUND THEN
      UPDATE "BUILDING"
      SET total_count = GREATEST(total_count - 1, 0)
      WHERE building_id = NEW.building_id;
      
      RAISE NOTICE 'OUT detected → Updated exit_time for tag_id=%', NEW.tag_id;
    ELSE
      RAISE WARNING 'No record found for OUT scan: tag_id=%', NEW.tag_id;
    END IF;

    RETURN NULL; 
  END IF;

  RETURN NULL;
END;
$$;

-- This trigger invokes the handle_scan_before function before any insert operation on the EntryExitLog table,
-- ensuring that each new entry or exit scan is processed according to the defined logic.

CREATE OR REPLACE TRIGGER process_scan_before
BEFORE INSERT ON "EntryExitLog"
FOR EACH ROW
EXECUTE FUNCTION handle_scan_before();

-- This block sets the timezone to Asia/Colombo for the database and various roles to ensure consistent timestamp 
-- handling across all operations and users.

ALTER DATABASE postgres SET timezone = 'Asia/Colombo';
ALTER ROLE postgres SET timezone = 'Asia/Colombo';
ALTER ROLE anon SET timezone = 'Asia/Colombo';
ALTER ROLE authenticated SET timezone = 'Asia/Colombo';
ALTER ROLE service_role SET timezone = 'Asia/Colombo';