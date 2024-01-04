DROP PROCEDURE IF EXISTS p_credit_note_link;

CREATE PROCEDURE p_credit_note_link()
	COMMENT '-name-PG-name--desc- Linking table for looking at revenue calculations of schools involving credit notes-desc-'
BEGIN
	-- Create an exit handler for when an error occurs in procedure
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			-- Get the error displayed
			GET DIAGNOSTICS CONDITION 1
				@sql_state = RETURNED_SQLSTATE,
				@errno = MYSQL_ERRNO,
				@errtxt = MESSAGE_TEXT;
-- Write the displayed error to the procedure_error_log table
			CALL analytics.p_error_logger('p_credit_note_link');
-- Resignal previous error to db
			RESIGNAL;
		END;


-- The schools with auto renewal are called automated auto renew in the note, making a combined table for them.

	DROP TABLE IF EXISTS all_schools_temp;

	CREATE TABLE all_schools_temp
		(id INT,
		 school_id INT,
		 date_added DATETIME,
		 credit_note INT,
		 KEY (school_id))
		COMMENT '-name-PG-name- -desc-Staging table for making linking table for school credit notes -desc-'
	SELECT ts.id,
				 ts.school_id,
				 ts.date_added,
				 0 AS credit_note
	FROM twinkl.twinkl_schoolsubscription AS ts

	UNION

	SELECT tsd.id,
				 tsd.school_id,
				 tsd.date_added,
				 1 AS credit_note
	FROM twinkl.twinkl_schoolsubscription_deleted AS tsd
	WHERE note LIKE '%automated%';

/* Made a linking table with only required columns and updated credit_type with following logic:
0	no  credit
1	credit and no alternative sub
2	credit and an alternative sub, we expect the renewed_by to have a duplicate

Updated the renewed_by column with sub_ux_id of the previous subs,
   Note: immediate successor of the sub with credit_type = 2 should have the same renewed_by sub as the one with credit_type = 2
 */

	DROP TABLE IF EXISTS linking_table_credit_note;

	CREATE TABLE linking_table_credit_note
		(school_id INT,
		 sub_ux_id INT,
		 credit_note INT,
		 date_added DATETIME,
		 credit_type INT COMMENT '0	no  credit
															1	credit and no alternative sub
															2	credit and an alternative sub, we expect the renewed_by to have a duplicate',
		 renewed_by INT,
		 KEY (school_id, sub_ux_id))
		COMMENT '-name-PG-name- -desc- Linking table for looking at revenue calculations of schools involving credit notes - -dim-B2B-dim- -gdpr-No issue-gdpr- -type-type-'
	SELECT ast.school_id,
				 ast.id AS sub_ux_id,
				 CASE
					 WHEN sussl.sub_id IS NULL AND ast.credit_note = 1
						 THEN ast.id
					 ELSE sussl.sub_id
				 END AS sub_id,
				 ast.credit_note,
				 ast.date_added,
				 CASE
					 WHEN ast.credit_note = 1 AND ast.date_added < (
																													 SELECT MAX(date_added)
																													 FROM all_schools_temp
																													 WHERE credit_note = 0
																														 AND school_id = ast.school_id
																												 )
						 THEN 2
					 WHEN ast.credit_note = 1
						 THEN 1
					 ELSE 0
				 END AS credit_type,
				 COALESCE(
								 (
									 SELECT MAX(id)
									 FROM all_schools_temp
									 WHERE school_id = ast.school_id
										 AND date_added < ast.date_added
										 AND credit_note = 0
								 ), 0
					 ) AS renewed_by
	FROM all_schools_temp AS ast
		LEFT JOIN sub_ux_school_sub_link AS sussl
			ON ast.id = sussl.sub_ux_id
	ORDER BY date_added ASC;

-- Dropped columns credit_note and date_added as not needed

	ALTER TABLE linking_table_credit_note
		DROP COLUMN credit_note,
		DROP COLUMN date_added;

-- Dropped staging table
	DROP TABLE IF EXISTS all_schools_temp;

END;
