
IMPORT FGL db

SCHEMA locksport

DEFINE m_manus DYNAMIC ARRAY OF RECORD LIKE manus.*
DEFINE m_locks DYNAMIC ARRAY OF RECORD LIKE locks.*
DEFINE m_pickTools DYNAMIC ARRAY OF RECORD LIKE tools.*
DEFINE m_tensionTools DYNAMIC ARRAY OF RECORD LIKE tools.*
DEFINE m_pickhist DYNAMIC ARRAY OF RECORD LIKE pick_hist.*
DEFINE m_save BOOLEAN = FALSE
MAIN

	CALL db.connect( "../database/locksport.db" )
	CALL db.chk_db(2)

	CALL getData()

	OPEN FORM p FROM "pick"
	DISPLAY FORM p

	CALL pick_history()
	DIALOG ATTRIBUTES(UNBUFFERED)
		DISPLAY ARRAY m_pickhist TO pickhist.*
			BEFORE ROW
				DISPLAY BY NAME m_pickhist[ arr_curr() ].*
		END DISPLAY
		COMMAND "Show Tools"
			CALL show_tools()
		COMMAND "Show Locks"
			CALL show_locks()
		COMMAND "Pick"
			CALL pick()

		ON ACTION close EXIT DIALOG
		ON ACTION quit EXIT DIALOG

	END DIALOG
	IF m_save THEN
		UNLOAD TO "../database/pick_hist.unl" SELECT * FROM pick_hist
	END IF
END MAIN
--------------------------------------------------------------------------------------------------------------
FUNCTION getData()
	DEFINE l_manu RECORD LIKE manus.*
	DEFINE l_lock RECORD LIKE locks.*
	DEFINE l_tool RECORD LIKE tools.*
	DEFINE l_row SMALLINT 

	LET l_row = 0
	DECLARE c_menus CURSOR FOR SELECT * FROM manus
	FOREACH c_menus INTO l_manu.*
		LET l_row = l_row + 1
		LET m_manus[ l_row ].* = l_manu.*
	END FOREACH

	DECLARE c_cblocks CURSOR FOR SELECT * FROM locks ORDER BY manu_code, lock_name
	FOREACH c_cblocks INTO l_lock.*
		LET m_locks[l_lock.lock_code].* = l_lock.*
	END FOREACH

	DECLARE c_cbtools CURSOR FOR SELECT * FROM tools ORDER BY tool_name, tool_width
	FOREACH c_cbtools INTO l_tool.*
		IF l_tool.tool_type = "T" THEN
			LET l_row = m_tensionTools.getLength() + 1
			LET m_tensionTools[l_row].* = l_tool.*
		ELSE
			LET l_row = m_pickTools.getLength() + 1
			LET m_pickTools[l_row].* = l_tool.*
		END IF
	END FOREACH
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION getManu(l_type CHAR(1), l_code CHAR(2))
	DEFINE x SMALLINT
	FOR x = 1 TO m_manus.getLength()
		IF l_type = m_manus[x].manu_type THEN
			IF m_manus[x].manu_code = l_code THEN RETURN m_manus[x].manu_name END IF
		END IF
	END FOR
	RETURN "Unknown"
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cb_toolmanu( l_cb ui.ComboBox )
	DEFINE l_row SMALLINT = 1
	FOR l_row = 1 TO m_manus.getLength()
		IF m_manus[ l_row ].manu_type = "T" THEN
			CALL l_cb.addItem( m_manus[ l_row ].manu_code ,  m_manus[ l_row ].manu_name )
		END IF
	END FOR
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cb_lockmanu( l_cb ui.ComboBox )
	DEFINE l_row SMALLINT = 1
	FOR l_row = 1 TO m_manus.getLength()
		IF m_manus[ l_row ].manu_type = "L" THEN
			CALL l_cb.addItem( m_manus[ l_row ].manu_code ,  m_manus[ l_row ].manu_name )
		END IF
	END FOR
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cb_lock( l_cb ui.ComboBox )
	DEFINE l_row SMALLINT = 1
	FOR l_row = 1 TO m_locks.getLength()
		CALL l_cb.addItem( m_locks[ l_row ].lock_code ,  getManu("L",m_locks[ l_row ].manu_code)||" "||m_locks[ l_row ].lock_name )
	END FOR
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cb_tool( l_cb ui.ComboBox )
	DEFINE l_row SMALLINT = 1
	DEFINE l_tool STRING
	IF l_cb.getColumnName() = "pick_tool_code" OR l_cb.getColumnName() = "apick_tool_code" THEN
		FOR l_row = 1 TO m_pickTools.getLength()
			IF NOT m_pickTools[ l_row ].broken THEN
				LET l_tool =  SFMT("%1  %2  %3",
														m_pickTools[ l_row ].tool_name,
														m_pickTools[ l_row ].tool_width,
														getManu("T",m_pickTools[ l_row ].manu_code))
				CALL l_cb.addItem( m_pickTools[ l_row ].tool_code ,  l_tool )
			END IF
		END FOR
	ELSE
		FOR l_row = 1 TO m_tensionTools.getLength()
			IF NOT m_tensionTools[ l_row ].broken THEN
				LET l_tool =  SFMT("%1 %2 %3", getManu("T",m_tensionTools[ l_row ].manu_code),
														m_tensionTools[ l_row ].tool_name,
														m_tensionTools[ l_row ].tool_width )
				CALL l_cb.addItem( m_tensionTools[ l_row ].tool_code ,  l_tool )
			END IF
		END FOR
	END IF
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION pick()
	DEFINE l_pick RECORD LIKE pick_hist.*
	DEFINE end_time DATETIME HOUR TO SECOND

	LET l_pick.date_picked = TODAY
	LET l_pick.time_picked = TIME
	LET l_pick.tension_method = "B"

	LET int_flag = FALSE
	INPUT BY NAME l_pick.*, end_time ATTRIBUTES( UNBUFFERED, WITHOUT DEFAULTS )
		ON ACTION now INFIELD time_picked
			LET l_pick.time_picked = TIME
			NEXT FIELD end_time
		ON ACTION now INFIELD end_time
			LET end_time = TIME
			LET l_pick.duration = duration(end_time,l_pick.time_picked)
			NEXT FIELD notes
		ON ACTION calc
			LET l_pick.duration = duration(end_time,l_pick.time_picked)
		AFTER FIELD end_time
			LET l_pick.duration = duration(end_time,l_pick.time_picked)
	END INPUT
	IF NOT int_flag THEN
		TRY
			INSERT INTO pick_hist VALUES( l_pick.* )
			LET m_save = TRUE
		CATCH
			ERROR SQLERRMESSAGE
		END TRY
		CALL pick_history()
	END IF

END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION duration(l_ed DATETIME HOUR TO SECOND, l_st DATETIME HOUR TO SECOND)
	DEFINE l_dur INTERVAL HOUR TO SECOND
	DEFINE l_str STRING
	LET l_dur = l_ed - l_st
	LET l_str = l_dur
	RETURN l_str
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION pick_history()
	DEFINE l_pick RECORD LIKE pick_hist.*
	DEFINE l_row SMALLINT = 0
	CALL m_pickhist.clear()
	DECLARE c_pickhist CURSOR FOR SELECT * FROM pick_hist
	FOREACH c_pickhist INTO l_pick.*
		LET l_row = l_row + 1
		LET m_pickhist[ l_row ].* = l_pick.*
	END FOREACH
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION show_locks()
	OPEN WINDOW locks WITH FORM "locks"
	DISPLAY ARRAY m_locks TO locks.*
		BEFORE ROW
			DISPLAY "../pics/"||m_locks[ arr_curr() ].lock_img||".jpg" TO img
	END DISPLAY
	CLOSE WINDOW locks
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION show_tools()
	DEFINE l_tools DYNAMIC ARRAY OF RECORD LIKE tools.*
	DEFINE l_row SMALLINT = 1
	DECLARE c_tools CURSOR FOR SELECT * FROM tools
	FOREACH c_tools INTO l_tools[ l_row ].*
		LET l_row = l_row + 1
	END FOREACH
	CALL l_tools.deleteElement( l_tools.getLength() )
	OPEN WINDOW tools WITH FORM "tools"
	DISPLAY ARRAY l_tools TO tools.*
		BEFORE ROW
			DISPLAY "../pics/"||l_tools[ arr_curr() ].tool_img||".jpg" TO img
	END DISPLAY
	CLOSE WINDOW tools
END FUNCTION