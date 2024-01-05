# List of active schools with their countries

SELECT COUNT(DISTINCT(school_id))
FROM analytics.sub_ux_school AS sus
WHERE CURDATE() BETWEEN sus.ux_start_date AND sus.ux_end_date;

SELECT DISTINCT(sus.school_id),
               dc.country,
               tsu.user_id,
               du.career_category_id
FROM analytics.sub_ux_school AS sus
	JOIN analytics.dx_school AS ds
		ON sus.school_id = ds.school_id
	JOIN analytics.dx_country AS dc
		ON ds.country_id = dc.country_id
	JOIN twinkl.twinkl_school_user AS tsu
		ON sus.school_id = tsu.school_id
	JOIN analytics.dx_user AS du
		ON tsu.user_id = du.user_id
WHERE CURDATE() BETWEEN sus.ux_start_date AND sus.ux_end_date;

SELECT COUNT(DISTINCT(sus.school_id))
FROM analytics.sub_ux_school AS sus
	LEFT JOIN twinkl.twinkl_school_user AS tsu
		ON sus.school_id = tsu.school_id
	LEFT JOIN analytics.dx_user AS du
		ON tsu.user_id = du.user_id
WHERE CURDATE() BETWEEN sus.ux_start_date AND sus.ux_end_date;

-- Main query
SELECT DISTINCT(sus.school_id),
               du.user_id,
               cco.neat_career_category,
               dc.country
FROM analytics.sub_ux_school AS sus
	LEFT JOIN twinkl.twinkl_school_user AS tsu
		ON sus.school_id = tsu.school_id
	LEFT JOIN analytics.dx_user AS du
		ON tsu.user_id = du.user_id
	LEFT JOIN career_category_overview AS cco
		ON du.career_category_id = cco.id
	LEFT JOIN dx_country AS dc
		ON du.country_id = dc.country_id
WHERE (CURDATE() BETWEEN sus.ux_start_date AND sus.ux_end_date)
		AND sus.school_id =1
 ;
