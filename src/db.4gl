DEFINE m_dbver STRING

FUNCTION connect(l_nam STRING)
	TRY
		CONNECT TO l_nam
	CATCH
		DISPLAY SFMT("Connect failed: %1 %2", STATUS, SQLERRMESSAGE )
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
	CALL dropTab( "tool_manu" )
	CALL dropTab( "tools" )
	CALL dropTab( "lock_manu" )
	CALL dropTab( "locks" )
	CALL dropTab( "pickhist" )
	CALL dropTab( "dbver" )
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cre_db()

	CALL drop_db()
	CALL cre_locks()
	CALL cre_tools()

	DISPLAY "Create table pickhist ..."
	CREATE TABLE pickhist (
		lock_code INT,
		pick_tool_code INT,
		tension_tool_code INT,
		tension_method CHAR(1),
		date_picked DATE,
		time_picked DATETIME HOUR TO SECOND,
		duration DATETIME HOUR TO SECOND
	)

	DISPLAY "Create table dbver ..."
	CREATE TABLE dbver (
		dbver SMALLINT
	)
	INSERT INTO dbver VALUES(1)
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cre_tools()
	DEFINE x SMALLINT

	DISPLAY "Create table tool_manu ..."
	CREATE TABLE tool_manu (
		manu_code CHAR(2),
		manu_name VARCHAR(60)
	)

	DISPLAY "Inserting tool_manu records ..."
	INSERT INTO tool_manu VALUES("SP","Sparrows")
	INSERT INTO tool_manu VALUES("DF","Dangerfield")
	INSERT INTO tool_manu VALUES("SO","SouthOrd")
	INSERT INTO tool_manu VALUES("PS","Petersons")
	INSERT INTO tool_manu VALUES("MP","Multipick")
	INSERT INTO tool_manu VALUES("GS","GoSo")
	INSERT INTO tool_manu VALUES("BG","Bang Good")
	INSERT INTO tool_manu VALUES("C1","Cheap set1")
	INSERT INTO tool_manu VALUES("C2","Cheap set2")
	INSERT INTO tool_manu VALUES("C3","Cheap set3")
	SELECT COUNT(*) INTO x FROM tool_manu
	DISPLAY SFMT("Inserted %1 tool_manu records.", x )

	DISPLAY "Create table tools ..."
	CREATE TABLE tools (
		tool_code SERIAL,
		manu_code CHAR(2),
		set_name VARCHAR(40),
		tool_type CHAR(1),
		tool_name VARCHAR(40),
		tool_width DECIMAL(5,3)
	)

	CALL insTools()
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cre_locks()
	DEFINE x SMALLINT

	DISPLAY "Create table lock_manu ..."
	CREATE TABLE lock_manu (
		manu_code CHAR(2),
		manu_name VARCHAR(60)
	)
	DISPLAY "Inserting lock_manu records ..."
	INSERT INTO lock_manu VALUES("ML","Master Locks")
	INSERT INTO lock_manu VALUES("AB","Abus")
	INSERT INTO lock_manu VALUES("ST","Sterling")
	INSERT INTO lock_manu VALUES("YL","Yale")
	INSERT INTO lock_manu VALUES("SP","Sparrows")
	INSERT INTO lock_manu VALUES("MX","Maxus")
	INSERT INTO lock_manu VALUES("WK","Wilko")
	SELECT COUNT(*) INTO x FROM lock_manu
	DISPLAY SFMT("Inserted %1 lock_manu records.", x )

	DISPLAY "Create table locks ..."
	CREATE TABLE locks (
		lock_code 		SERIAL,
		manu_code 		CHAR(2),
		lock_type 		CHAR(1),
		lock_name 		VARCHAR(40),
		picked 				BOOLEAN,
		pins 					SMALLINT,
		pintypes		 	VARCHAR(20),
		binding 			VARCHAR(20),
		pick_meth 		VARCHAR(20),
		max_pickwidth DECIMAL(5,3),
		tool_type 		VARCHAR(20),
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
		LOAD FROM "../database/tools.unl" INSERT INTO tools (manu_code, set_name, tool_type, tool_name, tool_width )
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
			lock_type 		,
			lock_name 		,
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
END FUNCTION