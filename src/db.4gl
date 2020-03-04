IMPORT os

IMPORT FGL lib

CONSTANT C_DBVER = 4
CONSTANT C_BACKUPDIR = "../../ls_backup"
CONSTANT C_DBPDIR = "../database"

PUBLIC DEFINE m_dbname STRING
PUBLIC DEFINE m_dbver SMALLINT
PUBLIC DEFINE m_dbtype STRING

DEFINE m_dbdir STRING
FUNCTION connect()
	LET m_dbname = fgl_getResource("ls.dbname")
	TRY
		CONNECT TO m_dbname
	CATCH
		CALL lib.error(SFMT("Connect failed: %1 %2", STATUS, SQLERRMESSAGE ))
		EXIT PROGRAM
	END TRY
	LET m_dbtype = fgl_getResource("dbi.default.driver")
	CALL chk_db()
	CALL fix_serials()
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION chk_db()
	TRY
		SELECT * INTO m_dbver FROM dbver
	CATCH
	END TRY
	IF m_dbver IS NULL OR m_dbver = 0 THEN CALL cre_db() END IF
	DISPLAY "DbVer:",m_dbver
	IF m_dbver < C_DBVER THEN
		IF NOT upd_db() THEN EXIT PROGRAM END IF
		DISPLAY "DbVer:",m_dbver," Now"
	END IF

END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cre_db()
	IF NOT os.path.exists(C_BACKUPDIR) THEN
		IF NOT os.path.mkdir(C_BACKUPDIR) THEN
			CALL lib.error( SFMT("Failed to mkdir %1", C_BACKUPDIR ))
		END IF
		LET m_dbdir = C_DBPDIR
	ELSE
		LET m_dbdir = C_BACKUPDIR
	END IF

	CALL drop_db()
	CALL cre_manus()
	CALL cre_locks()
	CALL cre_tools()
	CALL cre_pick_hist()

	DISPLAY "Create table dbver ..."
	CREATE TABLE dbver (
		dbver SMALLINT
	)
	LET m_dbver =1
	INSERT INTO dbver VALUES(m_dbver)

	IF NOT upd_db() THEN EXIT PROGRAM END IF

	CALL load_tools()
	CALL load_locks()
	CALL load_pick_hist()

	CALL save_db()
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION drop_db()
	CALL dropTab( "tools" )
	CALL dropTab( "locks" )
	CALL dropTab( "manus" )
	CALL dropTab( "pick_hist" )
	CALL dropTab( "dbver" )
	CALL dropTab( "lock_picks" )
	CALL dropTab( "session_template" )
	CALL dropTab( "session_locks" )
	CALL dropTab( "sessions" )
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION upd_db() RETURNS BOOLEAN
	DEFINE l_stmt STRING
	IF m_dbver = 1 THEN
		DISPLAY "Updating DB ..."
		LET l_stmt = "ALTER TABLE pick_hist ADD COLUMN attempts SMALLINT"
		TRY
			EXECUTE IMMEDIATE l_stmt
			UPDATE pick_hist SET attempts = 1
			UPDATE dbver SET dbver = 2
			LET m_dbver = 2
		CATCH
			CALL lib.error( SFMT("upd_db: %1 \nfailed: %2 %3",l_stmt,STATUS,SQLERRMESSAGE))
			RETURN FALSE
		END TRY
	END IF
	IF m_dbver = 2 THEN
		DISPLAY "Updating DB ..."
		LET l_stmt = "ALTER TABLE pick_hist ADD COLUMN session_id INTEGER"
		TRY
			EXECUTE IMMEDIATE l_stmt
		CATCH
			CALL lib.error( SFMT("upd_db: %1 \nfailed: %2 %3",l_stmt,STATUS,SQLERRMESSAGE))
			RETURN FALSE
		END TRY
		DISPLAY "Updating DB Create Table lock_picks ..."
		CREATE TABLE lock_picks ( 
			lock_code INTEGER,
			tensioner_code INTEGER,
			pick_code INTEGER,
			fav BOOLEAN
		)
		DISPLAY "Updating DB Create Table session_template ..."
		CREATE TABLE session_template (
			session_code SERIAL,
			session_desc VARCHAR(30),
			lock_code INTEGER,
			tensioner_code INTEGER,
			pick_code INTEGER
		)
		DISPLAY "Updating DB Create Table sessions ..."
		CREATE TABLE sessions (
			session_id SERIAL,
			session_code INTEGER,
			session_date DATE,
			started DATETIME HOUR TO SECOND,
			finished DATETIME HOUR TO SECOND
		)
		UPDATE dbver SET dbver = 3
		LET m_dbver = 3
	END IF
	IF m_dbver = 3 THEN
		CALL dropTab("session_template")
		DISPLAY "Updating DB Create Table session_template ..."
		CREATE TABLE session_template (
			session_code SERIAL,
			session_desc VARCHAR(30)
		)
		DISPLAY "Updating DB Create Table session_locks ..."
		CREATE TABLE session_locks (
			session_code INTEGER,
			lock_code INTEGER,
			tensioner_code INTEGER,
			pick_code INTEGER
		)
		UPDATE dbver SET dbver = 4
		LET m_dbver = 4
	END IF
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cre_pick_hist()

	DISPLAY "Create table pick_hist ..."
	CREATE TABLE pick_hist (
		pick_id 					SERIAL,
		lock_code 				INT,
		pick_tool_code 		INT,
		tension_tool_code INT,
		tension_method 		CHAR(1),
		date_picked 			DATE,
		time_picked 			DATETIME HOUR TO SECOND,
		duration 					DATETIME HOUR TO SECOND,
		notes 						VARCHAR(256)
	)
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cre_manus()
	DEFINE x SMALLINT

	DISPLAY "Create table manus ..."
	CREATE TABLE manus (
		manu_code CHAR(2),
		manu_type CHAR(1),
		manu_name VARCHAR(60)
	)

	DISPLAY "Inserting tool manus records ..."
	INSERT INTO manus VALUES("SP","T","Sparrows")
	INSERT INTO manus VALUES("DF","T","Dangerfield")
	INSERT INTO manus VALUES("SO","T","SouthOrd")
	INSERT INTO manus VALUES("PS","T","Petersons")
	INSERT INTO manus VALUES("MP","T","Multipick")
	INSERT INTO manus VALUES("GS","T","GoSo")
	INSERT INTO manus VALUES("BG","T","Bang Good")
	INSERT INTO manus VALUES("C1","T","Cheap set1")
	INSERT INTO manus VALUES("C2","T","Cheap set2")
	INSERT INTO manus VALUES("C3","T","Cheap set3")
	DISPLAY "Inserting lock manus records ..."
	INSERT INTO manus VALUES("ML","L","Master Locks")
	INSERT INTO manus VALUES("AB","L","Abus")
	INSERT INTO manus VALUES("ST","L","Sterling")
	INSERT INTO manus VALUES("YL","L","Yale")
	INSERT INTO manus VALUES("SP","L","Sparrows")
	INSERT INTO manus VALUES("MX","L","Maxus")
	INSERT INTO manus VALUES("WK","L","Wilko")
	SELECT COUNT(*) INTO x FROM manus
	DISPLAY SFMT("Inserted %1 manu records.", x )

END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cre_tools()

	DISPLAY "Create table tools ..."
	CREATE TABLE tools (
		tool_code SERIAL,
		manu_code CHAR(2),
		set_name VARCHAR(40),
		tool_type CHAR(1),
		tool_name VARCHAR(40),
		tool_width DECIMAL(5,3),
		tool_img VARCHAR(30),
		broken BOOLEAN
	)

END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cre_locks()

	DISPLAY "Create table locks ..."
	CREATE TABLE locks (
		lock_code 		SERIAL,
		manu_code 		CHAR(2),
		lock_name 		VARCHAR(40),
		lock_type 		CHAR(1),
		lock_img			VARCHAR(30),
		picked 				BOOLEAN,
		pins 					SMALLINT,
		pintypes		 	VARCHAR(20),
		binding 			VARCHAR(20),
		pick_meth 		VARCHAR(20),
		max_pickwidth DECIMAL(5,3),
		tool_type 		VARCHAR(30),
		tensioning 		VARCHAR(20),
		fasted_pick 	DATETIME HOUR TO SECOND,
		destroyed			BOOLEAN
	)

END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION dropTab( l_tab STRING )
	TRY
		EXECUTE IMMEDIATE "drop table "||l_tab
		DISPLAY "Dropped "||l_tab
	CATCH
		CALL lib.error( SFMT("Failed to drop %1: %2 %3", l_tab, STATUS, SQLERRMESSAGE ) )
	END TRY
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION load_tools()
	DEFINE x SMALLINT
	DEFINE m_file STRING
	LET m_file = os.path.join(m_dbdir,"tools.unl")
	IF NOT os.path.exists( m_file ) THEN
		LET m_file = os.path.join( C_DBPDIR,"tools.unl")
	END IF
	DISPLAY SFMT("Load tools from %1 ...",m_file)
	TRY
		LOAD FROM m_file INSERT INTO tools { (manu_code, set_name, tool_type, tool_name, tool_width, tool_img, broken )}
	CATCH
		CALL lib.error( SFMT("Failed to load tools.unl %1 %2", STATUS, SQLERRMESSAGE ) )
	END TRY
	SELECT COUNT(*) INTO x FROM tools
	DISPLAY SFMT("Loaded %1 tools.", x )
	IF x = 0 THEN	EXIT PROGRAM END IF
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION load_locks()
	DEFINE x SMALLINT
	DEFINE m_file STRING
	LET m_file = os.path.join(m_dbdir,"locks.unl")
	IF NOT os.path.exists( m_file ) THEN
		LET m_file = os.path.join( C_DBPDIR,"locks.unl")
	END IF
	DISPLAY SFMT("Load locks from %1 ...",m_file)
	TRY
		LOAD FROM m_file INSERT INTO locks {(
			manu_code 		,
			lock_name 		,
			lock_type 		,
			lock_img      ,
			picked 				,
			pins 					,
			pintypes		 	,
			binding 			,
			pick_meth 		,
			max_pickwidth ,
			tool_type 		,
			tensioning 		,
			fasted_pick 	,
			destroyed
			 )}
	CATCH
		CALL lib.error( SFMT("Failed to load locks.unl %1 %2", STATUS, SQLERRMESSAGE ) )
	END TRY
	SELECT COUNT(*) INTO x FROM locks
	DISPLAY SFMT("Loaded %1 locks.", x )
	IF x = 0 THEN	EXIT PROGRAM END IF
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION load_pick_hist()
	DEFINE x SMALLINT
	DEFINE m_file STRING
	LET m_file = os.path.join(m_dbdir,"pick_hist.unl")
	IF NOT os.path.exists( m_file ) THEN
		LET m_file = os.path.join( C_DBPDIR,"pick_hist.unl")
	END IF
	IF os.path.exists( m_file ) THEN
		DISPLAY SFMT("Load pick_hist from %1 ...",m_file)
		LOAD FROM m_file INSERT INTO pick_hist {(					
			lock_code,
			pick_tool_code,
			tension_tool_code,
			tension_method,
			date_picked,
			time_picked,
			duration,
			notes)}
	END IF
	SELECT COUNT(*) INTO x FROM pick_hist
	DISPLAY SFMT("Loaded %1 pick_hist.", x )
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION save_db()
	IF NOT os.path.exists(C_BACKUPDIR) THEN
		IF NOT os.path.mkdir(C_BACKUPDIR) THEN
			CALL lib.error( SFMT("Failed to mkdir %1", C_BACKUPDIR ))
			RETURN
		END IF
	END IF
	UNLOAD TO os.path.join(C_BACKUPDIR,"pick_hist.unl") SELECT * FROM pick_hist
	UNLOAD TO os.path.join(C_BACKUPDIR,"tools.unl") SELECT * FROM tools
	UNLOAD TO os.path.join(C_BACKUPDIR,"locks.unl") SELECT * FROM locks
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION fix_serials()
	DEFINE l_id INTEGER
  IF m_dbtype = "dbmpgs" THEN
    TRY
      SELECT MAX(pick_id) INTO l_id FROM pick_hist
      IF l_id IS NULL THEN LET l_id = 0 END IF
      LET l_id = l_id + 1
      DISPLAY "Fixing serial for pick_hist:",l_id
      EXECUTE IMMEDIATE "SELECT setval('pick_hist_pick_id_seq', "||l_id||")"
    CATCH
      CALL lib.error(SFMT("DB Error %1:%2", STATUS, SQLERRMESSAGE))
    END TRY
  END IF
END FUNCTION
