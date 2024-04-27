create table player_details(p_id integer, p_name varchar(100), l1_status integer,
						    l2_status integer, l1_code varchar(50), l2_code varchar(50));
							
select * from player_details;

create table level_details(p_id integer, Dev_id varchar(30), timestamp timestamp, stages_crossed integer,
						   level integer, difficulty varchar(50), kill_count integer, headshots_count integer, 
						   score integer, lives_earned integer);
						   
select * from level_details;

--1. Extract `P_ID`, `Dev_ID`, `PName`, and `Difficulty_level` of all players at Level 0

select p.p_id,l.dev_id,p.p_name,l.difficulty as Difficulty_level
from player_details as p
join level_details as l
on p.p_id = l.p_id
where l.level = 0
order by p.p_id;


--2. Find `Level1_code` wise average `Kill_Count` where `lives_earned` is 2, and at least 3 stages are crossed

select p.l1_code, cast(avg(l.kill_count) as int) as avg_kill_count
from player_details as p 
join level_details as l
on p.p_id = l.p_id
where l.lives_earned = 2 and l.stages_crossed >=3
group by p.l1_code;

--3. Find the total number of stages crossed at each difficulty level for Level 2 with players using `zm_series` devices. 
--Arrange the result in decreasing order of the total number of stages crossed

select difficulty as Difficulty_Level, count(stages_crossed) as Total_no_of_Stages
from level_details 
where level = 2 and dev_id like 'zm_%'
group by difficulty, stages_crossed
order by stages_crossed desc;

--4. Extract `P_ID` and the total number of unique dates for those players who have played games on multiple days

select p_id, count(distinct date(timestamp)) as total_unique_dates
from level_details
group by p_id
having count(distinct date(timestamp)) > 1;


--5. Find `P_ID` and levelwise sum of `kill_counts` where `kill_count` is greater than the average kill count for Medium difficulty

select l.p_id,l.level,sum(l.kill_count) as total_kill_count
from level_details as l
inner join(
           select avg(kill_count) as avg_kill_count
           from level_details
           where difficulty = 'Medium')
		   as avg_table on l.kill_count > avg_table.avg_kill_count
group by l.p_id,l.level;


--6. Find `Level` and its corresponding `Level_code` wise sum of lives earned, excluding Level 0. Arrange in ascending order of level.

select l.level,p.l1_code,p.l2_code, sum(lives_earned) as sum_of_lives_earned
from level_details as l
join player_details as p
on p.p_id = l.p_id
where l.level > 1
group by l.level, p.l1_code,  p,l2_code
order by l.level asc;


--7. Find the top 3 scores based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well.

select * from (
         select dev_id,score,difficulty,row_number() over(partition by dev_id order by score desc) as rank
         from level_details) as scores_details
where rank <=3
order by dev_id, rank;


--8. Find the `first_login` datetime for each device ID

select dev_id,min(timestamp) as first_login
from level_details
group by dev_id;


--9. Find the top 5 scores based on each difficulty level and rank them in increasing order using `Rank`. Display `Dev_ID` as well

select * from (
         select difficulty as difficulty_level, dev_id,score,row_number() over(partition by difficulty order by score desc) as rank
         from level_details) as scores_details
where rank <=5
order by difficulty_level, rank;


--10. Find the device ID that is first logged in (based on `start_datetime`) for each player (`P_ID`). 
--Output should contain player ID, device ID, and first login datetime

select p.p_id, l.dev_id, p.first_login_datetime
from (
      select p_id,min(timestamp) as first_login_datetime
      from level_details
      group by p_id) as p
join level_details as l
on p.p_id = l.p_id and p.first_login_datetime = l.timestamp
order by p.p_id


--11. For each player and date, determine how many `kill_counts` were played by the player so far.

--a) Using window functions

select  p_id, timestamp, sum(kill_count) over(partition by p_id order by timestamp rows between unbounded preceding and current row)
as cumulative_kill_count
from level_details;


--b) Without window functions

select l1.p_id, l1.timestamp, sum(l2.kill_count) as total_kill_count
from level_details l1
inner join level_details l2
on l1.p_id = l2.p_id and l2.timestamp <= l1.timestamp
group by l1.p_id, l1.timestamp
order by l1.p_id, l1.timestamp;


--12. Find the cumulative sum of stages crossed over `start_datetime` for each `P_ID`, excluding the most recent `start_datetime`

select p_id, timestamp, sum(stages_crossed) over (partition by p_id order by timestamp rows between unbounded preceding and 1 preceding)
as cumulative_stages_crossed
from level_details
order by p_id, timestamp;


--13. Extract the top 3 highest sums of scores for each `Dev_ID` and the corresponding `P_ID`.

select dev_id,p_id,sum_of_scores
from (
      select dev_id,p_id,sum(score) as sum_of_scores,row_number() over(partition by dev_id order by sum(score) desc) as rank
      from level_details
      group by dev_id,p_id) as scores_details
where rank <=3
order by dev_id, rank;

--14. Find players who scored more than 50% of the average score, scored by the sum of scores for each `P_ID`.

select p_id, sum(score) as sum_of_scores
from level_details
group by p_id
having sum(score) > (
                     select 0.5 * avg(sum_of_scores)
                     from (
					       select p_id, sum(score) as sum_of_scores
					       from level_details
					       group by p_id) as player_avg_scores
)
order by p_id;

--15. Create a stored procedure to find the top `n` `headshots_count` based on each `Dev_ID` and rank them in increasing order using `Row_Number`. 
--Display the difficulty as well

-- First simply displaying top 10

CREATE OR REPLACE FUNCTION GetPlayerScoreSum (player_id INT) RETURNS INT AS $$

DECLARE
total_score INT;
BEGIN
     SELECT SUM(Score) INTO total_score FROM Level_Details WHERE P_ID = player_id;
RETURN total_score;
END;
$$ LANGUAGE plpgsql;

--Call the function with a specific player id to see the output 

SELECT GetPlayerScoreSum (211) AS total_score;

    