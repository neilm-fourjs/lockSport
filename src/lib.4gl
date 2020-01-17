--------------------------------------------------------------------------------------------------------------
FUNCTION error( l_msg STRING )
	DISPLAY CURRENT,":",l_msg
	CALL fgl_winMessage("Error", l_msg,"exclamation")
END FUNCTION