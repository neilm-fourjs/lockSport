--SCHEMA locksport
IMPORT FGL db
MAIN

	CALL db.connect( "../database/locksport.db" )
	CALL db.chk_db(1)

	MENU
		COMMAND "Show Tools"
			CALL show_tools()
		COMMAND "Show Locks"
			CALL show_locks()
		ON ACTION close EXIT MENU
		ON ACTION quit EXIT MENU
	END MENU
END MAIN
--------------------------------------------------------------------------------------------------------------
FUNCTION show_tools()
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION show_locks()
END FUNCTION
--------------------------------------------------------------------------------------------------------------
