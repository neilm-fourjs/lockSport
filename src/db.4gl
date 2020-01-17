IMPORT os

DEFINE m_dbver STRING

FUNCTION connect(l_nam STRING)
	TRY
		CONNECT TO l_nam
	CATCH
		CALL fgl_winMessage("Error", SFMT("Connect failed: %1 %2", STATUS, SQLERRMESSAGE ),"exclamation")
		EXIT PROGRAM
	END TRY
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION chk_db(l_ver SMALLINT)
	TRY
		SELECT * INTO m_dbver FROM dbver
	CATCH
	END TRY
	IF m_dbver IS NULL OR m_dbver != l_ver THEN CALL cre_db() END IF
	DISPLAY "DbVer:",m_dbver
END FUNCTION
--------------------------------------------------------------------------------------------------------------

FUNCTION drop_db()
	CALL dropTab( "tools" )
	CALL dropTab( "locks" )
	CALL dropTab( "manus" )
	CALL dropTab( "pick_hist" )
	CALL dropTab( "dbver" )
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cre_db()

	CALL drop_db()
	CALL cre_manus()
	CALL cre_locks()
	CALL cre_tools()

	DISPLAY "Create table pick_hist ..."
	CREATE TABLE pick_hist (
		lock_code INT,
		pick_tool_code INT,
		tension_tool_code INT,
		tension_method CHAR(1),
		date_picked DATE,
		time_picked DATETIME HOUR TO SECOND,
		duration DATETIME HOUR TO SECOND,
		notes VARCHAR(256)
	)

	IF os.path.exists( "../database/pick_hist.unl" ) THEN
		LOAD FROM "../database/pick_hist.unl" INSERT INTO pick_hist
	END IF

	DISPLAY "Create table dbver ..."
	CREATE TABLE dbver (
		dbver SMALLINT
	)
	INSERT INTO dbver VALUES(1)
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

	CALL insTools()
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
		fasted_pick 	DATETIME HOUR TO SECOND
	)

	CALL insLocks()
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION dropTab( l_tab STRING )
	TRY
		EXECUTE IMMEDIATE "drop table "||l_tab
		DISPLAY "Dropped "||l_tab
	CATCH
		DISPLAY SFMT("Failed to drop %1: %2 %3", l_tab, STATUS, SQLERRMESSAGE )
	END TRY
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION insTools()
	DEFINE x SMALLINT
	DISPLAY "Load tools ..."
	TRY
		LOAD FROM "../database/tools.unl" 
			INSERT INTO tools (manu_code, set_name, tool_type, tool_name, tool_width, tool_img, broken )
	CATCH
		DISPLAY SFMT("Failed to load tools.unl %1 %2", STATUS, SQLERRMESSAGE )
	END TRY
	SELECT COUNT(*) INTO x FROM tools
	DISPLAY SFMT("Loaded %1 tools.", x )
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION insLocks()
	DEFINE x SMALLINT
	DISPLAY "Load locks ..."
	TRY
		LOAD FROM "../database/locks.unl" INSERT INTO locks (
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
			fasted_pick 	
			 )
	CATCH
		DISPLAY SFMT("Failed to load locks.unl %1 %2", STATUS, SQLERRMESSAGE )
	END TRY
	SELECT COUNT(*) INTO x FROM locks
	DISPLAY SFMT("Loaded %1 locks.", x )
	IF x = 0 THEN
		EXIT PROGRAM
	END IF
END FUNCTION