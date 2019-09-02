# Script to read from excel

#excel file 
$myfile="C:\Users\rainu\Desktop\Oracle_update.xlsx"
$sheetname="Mysheet"
$EndofLIne="ENDOFLINE"



#select set statment
$selectset=@"
  set echo off;
  set pagesize 0
  set head off;
  set feedback off;
  set pause off;
  set verify off;
  set trimspool on;
  set linesize 15000;
  set termout off;
"@

#select with serveroutput on
$selectset2=@"
  set echo off;
  set pagesize 0
  set head off;
  set feedback off;
  set pause off;
  set verify off;
  set trimspool on;
  set linesize 15000;
  set termout off;
  set serveroutput on;
"@

$updateend=@"
 if sql%rowcount=1 then
  dbms_output.put_line('S');
  else
  dbms_output.put_line('F');
  end if;
  end;
  /
"@

#release com object
function Release-Ref ($ref) {
([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
}






# DBCONNECTON1
function DBHR ($sql)
{
return $sql | sqlplus -silent hr/hr@localhost:1521/xe
}

# DBCONNECTON2
function DBHR2 ($sql)
{
return $sql | sqlplus -silent hr/hr@localhost:1521/xe
}

# DBCONNECTON3
function DBHR3 ($sql)
{
return $sql | sqlplus -silent hr/hr@localhost:1521/xe
}


#excel object
$exobj = New-Object -ComObject Excel.Application

# open excel workbook  
$workbook = $exobj.Workbooks.Open($myfile)

# open worksheet
$worksheet = $workbook.Sheets.Item($sheetname)

#entire first column
$Range = $worksheet.Range("A1").EntireColumn

#count of rows in the excel
$lastrow = $Range.find($EndofLIne).row


##3 FOR EVERY ROW IN THE EXCEL I.E EVERY TABLE
for ($row=2 ;$row -lt $lastrow;$row++) {

#pick table name from excel
$tblname=$worksheet.cells.item($row,1).text

#pick the column to update excel
$updatecol=$worksheet.cells.item($row,2).text

#primary keys column query
$PK_col_nmq=@"
select listagg(COLUMN_NAME,',') within group(order by TABLE_NAME) PK_COLUMNS
from 
(SELECT cols.table_name, cols.column_name, cols.position, cons.status, cons.owner
FROM all_constraints cons, all_cons_columns cols
WHERE cols.table_name = '$tblname'
AND cons.STATUS='ENABLED'
AND cons.constraint_type = 'P'
AND cons.constraint_name = cols.constraint_name
AND cons.owner = cols.owner
ORDER BY cols.table_name, cols.position);
"@

$PK_col_nmq1=$selectset+"`n"+$PK_col_nmq

#fetch primary key columnns
$PK_col_nm = DBHR $PK_col_nmq1

### UPDATE THE PRIMARY key column names 
$worksheet.Cells.Item($row,3)=$PK_col_nm

#query primary columns data
$PK_col_dataq=@"
  set colsep '|';
  select $PK_col_nm from $tblname
  where
  rownum<2;
"@

$PK_col_dataq1=$selectset+"`n"+$PK_col_dataq

#fetch primary key data
$PK_col_data = DBHR $PK_col_dataq1

#removed added spaces from data
$PK_col_data = $PK_col_data.Trim()

### UPDATE THE PRIMARY key column names 
$worksheet.Cells.Item($row,4)=$PK_col_data


#no of primary key columns
$PK_col_count = $PK_col_data.Split('|').length


write-host "TAble " $tblname  "sample data " $PK_col_data "len " $PK_col_count

########## fetch column data for backup ############

if ($PK_col_count -eq 1) {

$UP_col_dataq=@"
  select $updatecol from $tblname
  where
  $PK_col_nm='$PK_col_data';
"@

}
#2 column as primary key
elseif ($PK_col_count -eq 2) {

$pkcol1_nm,$pkcol2_nm=$PK_col_nm.Split(',')
$pkdat1,$pkdat2=$PK_col_data.Split('|').trim()

$UP_col_dataq=@"
  select $updatecol from $tblname
  where
  $pkcol1_nm='$pkdat1' and
  $pkcol2_nm='$pkdat2';
"@

}

$UP_col_dataq1=$selectset+"`n"+$UP_col_dataq

$UP_col_data=DBHR $UP_col_dataq1

########## fetch column data for backup end ############


#form the update statement if only 1 column in primary key
if ($PK_col_count -eq 1) {

$updatestmt=@"
  update $tblname set $updatecol=$updatecol||'.'
  where
  $PK_col_nm='$PK_col_data';
"@

}
#2 column as primary key
elseif ($PK_col_count -eq 2) {

$pkcol1_nm,$pkcol2_nm=$PK_col_nm.Split(',')
$pkdat1,$pkdat2=$PK_col_data.Split('|').trim()

$updatestmt=@"
  update $tblname set $updatecol=$updatecol| |'.'
  where
  $pkcol1_nm='$pkdat1' and
  $pkcol2_nm='$pkdat2';
"@

}

$updatestmt1=$selectset2+"`n"+"begin"+"`n"+$updatestmt+"`n"+$updateend
echo $updatestmt1

#run the update statement
$UP_status=DBHR $updatestmt1


echo $UP_status

#update the status in excel
$worksheet.Cells.Item($row,5)=$UP_status


#update old value of updated column in excel
#$worksheet.Cells.Item($row,4)=$UP_col_data



##FETCH data again
$UP_col_data_after=DBHR $UP_col_dataq1


#update new value of updated column in excel
#$worksheet.Cells.Item($row,5)=$UP_col_data_after



########## COMPARE AND UPDATE BLOCK #####################

#FETCH DATA FROM SECOND DB
Write-Host "waiting for 5 seconds"
Start-Sleep -Seconds 1

$UP_col_data_2DB=DBHR2 $UP_col_dataq1

if ($UP_col_data_2DB.equals($UP_col_data_after)) {
$worksheet.Cells.Item($row,6)='S'
}
else {
$worksheet.Cells.Item($row,6)='E'
}

Write-Host "waiting for 5 seconds"
Start-Sleep -Seconds 1

#FETCH DATA FROM THIRD DB
$UP_col_data_3DB=DBHR3 $UP_col_dataq1

if ($UP_col_data_3DB.equals($UP_col_data_after)) {
$worksheet.Cells.Item($row,7)='S'
}
else {
$worksheet.Cells.Item($row,7)='E'
}


########## COMPARE AND UPDATE BLOCK END #####################


$workbook.save()

}
$workbook.close()

$exobj.quit()

Release-Ref($exobj)

 ###########################################################

###insert stmt sql file format
set echo off;
set feedback off;
set serveroutput on;
spool insert_log.log
begin
insert into table1 (column1,column2,column3) values ('1','2','21-DEC-1991');
dbms_output.put_line('S');
exception when others then
dbms_output.put_line('E');
end;
/
begin
insert into table2 (column1,column2,column3) values (1,'2','21-DEC-1991');
dbms_output.put_line('S');
exception when others then
dbms_output.put_line('E');
end;
/
begin
insert into table3 (column1,column2,column3) values ('1','2',NULL);
dbms_output.put_line('S');
exception when others then
dbms_output.put_line('E');
end;
/
begin
insert into table4 (column1,column2,column3) values ('1','2','21-DEC-1991');
dbms_output.put_line('S');
exception when others then
dbms_output.put_line('E');
end;
/
spool off;
commit;

###the spool OUTPUT of insert file
S                                                                               
S                                                                               
E                                                                               
S                                                                               

##the above can be used to update the excel with the insert status of the specific column

### count statement sql file ########
set feedback off;
set echo off;
set heading off;
SET TRIMSPOOL off;
set termout off;
spool count_log.log
select count(*) from table1 where column1=1;
select count(*) from table2 where column1=1;
select count(*) from table3 where column1=1;
select count(*) from table4 where column1=1;
spool off;

##count spool output 

         2                                                                      

         4                                                                      

         2                                                                      

         4                                                                      

##to remove blank lines and space from the log file
(gc count_log.log) | ? {$_.trim() -ne "" } | ForEach-Object{$_.Replace(' ',$null)} |set-content count_log.log

###update statement sql file

set echo off;
set feedback off;
set serveroutput on;
spool update_log.log
begin
update table1 set column3=to_Date('21-12-1991','DD-MM-YYYY') where column1='1';
if sql%rowcount=1 then
dbms_output.put_line('S');
elsif sql%rowcount=0 then
dbms_output.put_line('E');
end if;
exception when others then
dbms_output.put_line('E');
end;
/
begin
update table2 set column3=to_Date('21-12-1991','DD-MM-YYYY') where column1=1;
if sql%rowcount=1 then
dbms_output.put_line('S');
elsif sql%rowcount=0 then
dbms_output.put_line('E');
end if;
exception when others then
dbms_output.put_line('E');
end;
/
begin
update table3 set column3=to_Date('21-12-1991','DD-MM-YYYY') where column1='1';
if sql%rowcount=1 then
dbms_output.put_line('S');
elsif sql%rowcount=0 then
dbms_output.put_line('E');
end if;
exception when others then
dbms_output.put_line('E');
end;
/
begin
update table4 set column3=to_Date('21-12-1991','DD-MM-YYYY') where column1='1';
if sql%rowcount=1 then
dbms_output.put_line('S');
elsif sql%rowcount=0 then
dbms_output.put_line('E');
end if;
exception when others then
dbms_output.put_line('E');
end;
/
spool off;
commit;


#######update log file
S                                                                               
S                                                                               
E                                                                               
S                                                                               

###select sql file
spool select_log.log
select 'TABLE1',MAX(column3) from table1 where column1='1';
select 'TABLE2',MAX(column3) from table2 where column1='1';
select 'TABLE3',MAX(column3) from table3 where column1='1';
select 'TABLE4',MAX(column3) from table4 where column1='1';
spool off;


####select log file output

TABLE1 21-DEC-91                                                                

TABLE2 21-DEC-91                                                                

TABLE3                                                                          

TABLE4 21-DEC-91                                                                


##### remove the blank lines from the log file
(gc select_log.log) | ? {$_.trim() -ne "" } | set-content select_log.log


###delete sql file
set echo off;
set feedback off;
set serveroutput on;
spool delete_log.log
begin
delete from table1 where column1='1';
if sql%rowcount=1 then
dbms_output.put_line('S');
elsif sql%rowcount=0 then
dbms_output.put_line('E');
end if;
exception when others then
dbms_output.put_line('E');
end;
/
begin
delete from table2 where column1='1';
if sql%rowcount=1 then
dbms_output.put_line('S');
elsif sql%rowcount=0 then
dbms_output.put_line('E');
end if;
exception when others then
dbms_output.put_line('E');
end;
/
begin
delete from table3 where column1='1';
if sql%rowcount=1 then
dbms_output.put_line('S');
elsif sql%rowcount=0 then
dbms_output.put_line('E');
end if;
exception when others then
dbms_output.put_line('E');
end;
/
begin
delete from table4 where column1='1';
if sql%rowcount=1 then
dbms_output.put_line('S');
elsif sql%rowcount=0 then
dbms_output.put_line('E');
end if;
exception when others then
dbms_output.put_line('E');
end;
/
spool off;
commit;

###delete log file output
S                                                                               
S                                                                               
E                                                                               
S                                                                               



remove lines with unwanted character
get-content new_count.log | select-string -pattern 'SQL>' -notmatch | set-content new_count1.log


read file one after onother
$regex='SQL>'

Get-Content C:\Users\rainu\Desktop\Sample_File\new_count.log | ForEach-Object {
    if ($_ -notmatch $regex -and $_.trim() -ne "") 
    {     
           if($_.trim() -eq 1)
            {WRITE-HOST 'update column as S'}
    }
    
    }  
	
Get-Content C:\Users\rainu\Desktop\Sample_File\select_out.log | ForEach-Object {
    if ($_ -notmatch $regex -and $_.trim() -ne "") 
    {     
	WRITE-HOST $_
    }
    
    }  	
    ###########################################################
