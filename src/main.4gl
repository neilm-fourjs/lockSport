
IMPORT os
IMPORT FGL db
IMPORT FGL lib

SCHEMA locksport

DEFINE m_manus DYNAMIC ARRAY OF RECORD LIKE manus.*
DEFINE m_locks DYNAMIC ARRAY OF RECORD LIKE locks.*
DEFINE m_pickTools DYNAMIC ARRAY OF RECORD LIKE tools.*
DEFINE m_tensionTools DYNAMIC ARRAY OF RECORD LIKE tools.*
DEFINE m_pickhist DYNAMIC ARRAY OF RECORD LIKE pick_hist.*
TYPE t_pickhist_scr RECORD
		pick_id 					INT,
		lock_code 				INT,
		tool_logo					STRING,
		pick_tool_code 		INT,
		tension_tool_code INT,
		tension_method 		CHAR(1),
		datetime_picked		DATETIME YEAR TO SECOND,
		duration 					DATETIME HOUR TO SECOND,
		notes 						VARCHAR(256),
		attempts					SMALLINT
	END RECORD
DEFINE m_pickhist_scr DYNAMIC ARRAY OF t_pickhist_scr
DEFINE m_pickhist_col DYNAMIC ARRAY OF RECORD
		fld1 STRING,
		fld2 STRING,
		fld3 STRING,
		fld4 STRING,
		fld5 STRING,
		fld6 STRING,
		fld7 STRING,
		fld8 STRING,
		fld9 STRING,
		fld10 STRING
	END RECORD
	
DEFINE m_save BOOLEAN = FALSE
MAIN
	CALL db.connect()
	CALL getData()

	OPEN FORM p FROM "pick"
	DISPLAY FORM p
	CALL ui.Interface.setImage("fa-unlock")
	CALL fgl_setTitle( SFMT("Locksport DB: %1 : %2", db.m_dbName, db.m_dbVer ) )

	DIALOG ATTRIBUTES(UNBUFFERED)
		DISPLAY ARRAY m_pickhist_scr TO pickhist.*
			BEFORE DISPLAY
				CALL pick_history()
			BEFORE ROW
				DISPLAY BY NAME m_pickhist[ arr_curr() ].*
				DISPLAY m_pickhist_scr[ arr_curr() ].tool_logo TO tool_logo
				DISPLAY tool_img( m_pickhist[ arr_curr() ].pick_tool_code ) TO tool_img
				DISPLAY lock_img( m_pickhist[ arr_curr() ].lock_code ) TO lock_img
			ON ACTION UPDATE
				LET int_flag = FALSE
				INPUT BY NAME m_pickhist[ arr_curr() ].* ATTRIBUTES(WITHOUT DEFAULTS)
				IF NOT int_flag THEN
					UPDATE pick_hist SET pick_hist.* = m_pickhist[arr_curr()] .* WHERE pick_id = m_pickhist[ arr_curr() ].pick_id
					CALL pick_history()
				END IF
		END DISPLAY

		ON ACTION pick CALL pick()
		ON ACTION list_tools CALL show_tools()
		ON ACTION list_locks CALL show_locks()

		ON ACTION db_reset
			IF fgl_winQuestion("Confirm","Are you sure?","No","Yes|No","question",0) = "Yes" THEN
				CALL db.cre_db()
				CALL getData()
			END IF
		ON ACTION db_save CALL db.save_db()

		ON ACTION close EXIT DIALOG
		ON ACTION quit EXIT DIALOG

	END DIALOG
	IF m_save THEN CALL db.save_db() END IF
END MAIN
--------------------------------------------------------------------------------------------------------------
FUNCTION getData()
	DEFINE l_manu RECORD LIKE manus.*
	DEFINE l_lock RECORD LIKE locks.*
	DEFINE l_tool RECORD LIKE tools.*
	DEFINE l_row SMALLINT 

	CALL m_manus.clear()
	CALL m_locks.clear()
	CALL m_tensionTools.clear()
	CALL m_pickTools.clear()

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

	DECLARE c_cbtools CURSOR FOR SELECT * FROM tools ORDER BY tool_name, tool_width, manu_code
	FOREACH c_cbtools INTO l_tool.*
		IF l_tool.tool_type = "T" THEN
			LET l_row = m_tensionTools.getLength() + 1
			LET m_tensionTools[l_row].* = l_tool.*
		ELSE
			LET l_row = m_pickTools.getLength() + 1
			LET m_pickTools[l_row].* = l_tool.*
		END IF
	END FOREACH
	DISPLAY SFMT("Loaded: %1 Locks, %2 Picks, %3 Tension Tools", m_locks.getLength(), m_pickTools.getLength(), m_tensionTools.getLength())

	CALL pick_history()
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION getManu(l_type CHAR(1), l_code CHAR(2)) RETURNS STRING
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
		CALL l_cb.addItem( m_locks[ l_row ].lock_code ,  SFMT("%2 %3 (%1)",m_locks[ l_row ].lock_code,getManu("L",m_locks[ l_row ].manu_code),m_locks[ l_row ].lock_name) )
	END FOR
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION cb_tool( l_cb ui.ComboBox )
	DEFINE l_row SMALLINT = 1
	DEFINE l_tool STRING
	IF l_cb.getColumnName() = "pick_tool_code" OR l_cb.getColumnName() = "apick_tool_code" THEN
		FOR l_row = 1 TO m_pickTools.getLength()
			IF NOT m_pickTools[ l_row ].broken THEN
				LET l_tool =  SFMT("%1 (%2) %3",
														m_pickTools[ l_row ].tool_name,
														m_pickTools[ l_row ].tool_width,
														getManu("T",m_pickTools[ l_row ].manu_code))
				CALL l_cb.addItem( m_pickTools[ l_row ].tool_code ,  l_tool )
			END IF
		END FOR
	ELSE
		FOR l_row = 1 TO m_tensionTools.getLength()
			IF NOT m_tensionTools[ l_row ].broken THEN
				LET l_tool =  SFMT("%1 %2 (%3)", getManu("T",m_tensionTools[ l_row ].manu_code),
														m_tensionTools[ l_row ].tool_name,
														m_tensionTools[ l_row ].tool_width )
				CALL l_cb.addItem( m_tensionTools[ l_row ].tool_code ,  l_tool )
			END IF
		END FOR
	END IF
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION tool_img( l_code SMALLINT ) RETURNS STRING
	DEFINE x SMALLINT
	DEFINE l_img STRING
	FOR x = 1 TO m_pickTools.getLength()
		IF m_pickTools[ x ].tool_code = l_code THEN LET l_img = m_pickTools[ x ].tool_img||".jpg" END IF
	END FOR
	DISPLAY "ToolImg:",l_img
	RETURN l_img
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION lock_img( l_code SMALLINT ) RETURNS STRING
	DEFINE x SMALLINT
	DEFINE l_img STRING
	FOR x = 1 TO m_locks.getLength()
		IF m_locks[ x ].lock_code = l_code THEN LET l_img = m_locks[ x ].lock_img||".jpg" END IF
	END FOR
	DISPLAY "LockImg:",l_img
	RETURN l_img
END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION pick()
	DEFINE l_pick RECORD LIKE pick_hist.*
	DEFINE end_time DATETIME HOUR TO SECOND

	LET l_pick.date_picked = TODAY
	LET l_pick.tension_method = "B"
	LET l_pick.attempts = 1

	LET int_flag = FALSE

	INPUT BY NAME l_pick.*, end_time ATTRIBUTES(UNBUFFERED, WITHOUT DEFAULTS )
		ON CHANGE lock_code
				DISPLAY lock_img( l_pick.lock_code ) TO lock_img

		ON CHANGE pick_tool_code
				DISPLAY tool_img( l_pick.pick_tool_code ) TO tool_img

		BEFORE FIELD time_picked
			LET l_pick.time_picked = TIME

		ON ACTION now INFIELD time_picked
			LET l_pick.time_picked = TIME
			NEXT FIELD end_time
		ON ACTION now INFIELD end_time
			LET end_time = TIME
			LET l_pick.duration = duration(end_time,l_pick.time_picked)
			NEXT FIELD notes

		ON ACTION calc
			LET l_pick.duration = duration(end_time,l_pick.time_picked)
		ON ACTION plus
			LET l_pick.attempts = l_pick.attempts + 1

		AFTER FIELD end_time
			LET l_pick.duration = duration(end_time,l_pick.time_picked)
		ON ACTION fail
			LET l_pick.duration = "00:00:00"
		ON ACTION sample
			IF sample() THEN
				DISPLAY "Sample:", arr_curr()
				LET l_pick.pick_id = m_pickhist_scr[ arr_curr() ].pick_id
				LET l_pick.lock_code = m_pickhist_scr[ arr_curr() ].lock_code
				LET l_pick.pick_tool_code = m_pickhist_scr[ arr_curr() ].pick_tool_code
				LET l_pick.tension_tool_code  = m_pickhist_scr[ arr_curr() ].tension_tool_code
				LET l_pick.tension_method =  m_pickhist_scr[ arr_curr() ].tension_method
			END IF
	END INPUT

	IF NOT int_flag THEN
		TRY
			INSERT INTO pick_hist VALUES  l_pick.*
			LET m_save = TRUE
		CATCH
			ERROR SQLERRMESSAGE
		END TRY
		CALL pick_history()
	END IF

END FUNCTION
--------------------------------------------------------------------------------------------------------------
FUNCTION sample() RETURNS BOOLEAN
	LET int_flag = FALSE
	DISPLAY ARRAY m_pickhist_scr TO pickhist.*
	IF int_flag THEN LET int_flag = FALSE RETURN FALSE END IF
	RETURN TRUE
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
	DEFINE l_dte DATETIME YEAR TO DAY
	DEFINE l_row SMALLINT = 0
	DEFINE l_tool_id SMALLINT
	DEFINE l_d ui.Dialog
	CALL m_pickhist.clear()
	CALL m_pickhist_col.clear()
	DECLARE c_pickhist CURSOR FOR SELECT * FROM pick_hist
	FOREACH c_pickhist INTO l_pick.*
		LET l_row = l_row + 1
		LET m_pickhist_col[ l_row ].fld1 = "black"
		LET m_pickhist[ l_row ].* = l_pick.*
		IF l_pick.duration = "00:00:00" THEN
			DISPLAY "Row:",l_row," Failed!"
			LET m_pickhist_col[ l_row ].fld4 = "red"
			LET m_pickhist_col[ l_row ].fld2 = "red"
		END IF
		
		LET l_dte = l_pick.date_picked
		LET m_pickhist_scr[ l_row ].datetime_picked = l_dte||" "||l_pick.time_picked
		LET m_pickhist_scr[ l_row ].duration = l_pick.duration
		LET m_pickhist_scr[ l_row ].notes = l_pick.notes
		LET m_pickhist_scr[ l_row ].pick_tool_code = l_pick.pick_tool_code
		LET m_pickhist_scr[ l_row ].tension_method = l_pick.tension_method
		LET m_pickhist_scr[ l_row ].tension_tool_code = l_pick.tension_tool_code
		LET m_pickhist_scr[ l_row ].lock_code = l_pick.lock_code
		LET m_pickhist_scr[ l_row ].pick_id = l_pick.pick_id
		LET m_pickhist_scr[ l_row ].attempts = l_pick.attempts
		FOR l_tool_id = 1 TO m_pickTools.getLength()
			IF l_pick.pick_tool_code = m_pickTools[ l_tool_id ].tool_code THEN EXIT FOR END IF
		END FOR
		DISPLAY "Row:",l_row," Manu:",m_pickTools[ l_tool_id ].manu_code, ":",m_pickhist_scr[ l_row ].datetime_picked
		CASE m_pickTools[ l_tool_id ].manu_code
			WHEN "SP" LET m_pickhist_scr[ l_row ].tool_logo = "sparrows_logo.png"
			WHEN "DF" LET m_pickhist_scr[ l_row ].tool_logo = "dangerfield_logo.png"
		END CASE
	END FOREACH
	LET l_d = ui.Dialog.getCurrent()
	IF l_d IS NOT NULL THEN
		DISPLAY "applying colours"
		CALL l_d.setArrayAttributes("pickhist",m_pickhist_col)
	END IF
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