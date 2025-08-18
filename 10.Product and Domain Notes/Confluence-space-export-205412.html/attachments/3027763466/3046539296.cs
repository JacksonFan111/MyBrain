/*
   Microsoft SQL Server Integration Services Script Task
   Write scripts using Microsoft Visual C# 2008.
   The ScriptMain is the entry point class of the script.
*/

using System;
using System.Data;
using Microsoft.SqlServer.Dts.Runtime;
using System.Windows.Forms;
using System.IO;
using System.Data.SqlClient;

namespace ST_415f66d7d3ad4b26a324ffdb35838d15.csproj
{
    [Microsoft.SqlServer.Dts.Tasks.ScriptTask.SSISScriptTaskEntryPointAttribute]
    public partial class ScriptMain : Microsoft.SqlServer.Dts.Tasks.ScriptTask.VSTARTScriptObjectModelBase
    {

        #region VSTA generated code
        enum ScriptResults
        {
            Success = Microsoft.SqlServer.Dts.Runtime.DTSExecResult.Success,
            Failure = Microsoft.SqlServer.Dts.Runtime.DTSExecResult.Failure
        };
        #endregion

        /*
		The execution engine calls this method when the task executes.
		To access the object model, use the Dts property. Connections, variables, events,
		and logging features are available as members of the Dts property as shown in the following examples.

		To reference a variable, call Dts.Variables["MSqlDataReader dr yCaseSensitiveVariableName"].Value;
		To post a log entry, call Dts.Log("This is my log text", 999, null);
		To fire an event, call Dts.Events.FireInformation(99, "test", "hit the help message", "", 0, true);

		To use the connections collection use something like the following:
		ConnectionManager cm = Dts.Connections.Add("OLEDB");
		cm.ConnectionString = "Data Source=localhost;Initial Catalog=AdventureWorks;Provider=SQLNCLI10;Integrated Security=SSPI;Auto Translate=False;";

		Before returning from this method, set the value of Dts.TaskResult to indicate success or failure.
		
		To open Help, press F1.
	*/

        public void Main()
        {
            string FileFullPath = "";
            string FileName = "";
            SqlConnection myADONETConnection = new SqlConnection();
            myADONETConnection = (SqlConnection)(Dts.Connections["SQLDBConn"].AcquireConnection(Dts.Transaction) as SqlConnection);
            SqlDataReader dr = null;
            try
            {

                //Declare Variables
                //string SQLStatement = Dts.Variables["User::SQLStatement"].Value.ToString();
                string FileDelimiter = Dts.Variables["User::FileDelimiter"].Value.ToString();
                int TotRowsChunk = Convert.ToInt32(Dts.Variables["User::TotRowsChunk"].Value);
                //string FileExtension = Dts.Variables["User::FileExtension"].Value.ToString();



                //USE ADO.NET Connection from SSIS Package to get data from table
                

                //Logging 
               

                //Read list of Tables with Schema from Database
                //string query = "SELECT [FileName]+'_'+CONVERT(varchar(10), GETDATE(), 121)+'.'+FileExt [FileName],FileDestination,SQLStatement FROM " + SQLStatement;
                // string query = "SELECT [FileName],FileDestination, SQLStatement FROM [ETL].[vw_SSIS_Packages_Config]";

                //MessageBox.Show(query.ToString());
                //   SqlCommand cmd = new SqlCommand(query, myADONETConnection);
                //  DataTable dt = new DataTable();
                //     dt.Load(cmd.ExecuteReader());

                //Loop through datatable(dt) that has schema and table names
                // foreach (DataRow dt_row in dt.Rows)
                //   {
                FileName = Dts.Variables["User::FileName"].Value.ToString();
                string TableName = Dts.Variables["User::TableName"].Value.ToString();
                string FileDestination = Dts.Variables["User::FileDestination"].Value.ToString();
                string SQLQuery = Dts.Variables["User::SQLQuery"].Value.ToString();
                string QueryType = Dts.Variables["User::QueryType"].Value.ToString();

                string logQuery = " EXEC [ETL].[usp_BatchLog] @BatchID=0,@BatchStatus='In Progress',@TableName='"+TableName+" - Exporting to CSV',@TableStatus='Started' ";
                SqlCommand data_cmdlog = new SqlCommand(logQuery, myADONETConnection);
                data_cmdlog.ExecuteNonQuery();

                //Get the data for a table into data table 
                string data_query = SQLQuery; //"SELECT * FROM [" + SchemaName + "].[" + SQLQuery + "]";
                SqlCommand data_cmd = new SqlCommand(data_query, myADONETConnection);
                if (QueryType=="Proc")
                {
                    data_cmd.CommandType = CommandType.StoredProcedure;
                }
                data_cmd.CommandTimeout = 0;
                //DataTable d_table = new DataTable();
                // d_table.Load(data_cmd.ExecuteReader());
                dr = data_cmd.ExecuteReader();
                int rowno = 1;
                int batchid = 1;
               

                if (dr.HasRows)
                {


                    int ColumnCount = dr.FieldCount;
                    StreamWriter sw = null;
                    // Write All Rows to the File
                    while (dr.Read())
                    {
                        if (rowno == 1)
                        {

                            FileFullPath = FileDestination + "" + FileName + "_" + DateTime.Now.ToString("yyyy-MM-ddTHHmm_" + batchid.ToString() + "") + ".csv"; //DestinationFolder + "\\" + SchemaName + "_" + SQLQuery + "_" + datetime + FileExtension;
                            //ColumnStyle Write
                            sw = new StreamWriter(FileFullPath, false);

                            // Write the Header Row to File

                            for (int ic = 0; ic < ColumnCount; ic++)
                            {
                                sw.Write(dr.GetName(ic).ToString());
                                if (ic < ColumnCount - 1)
                                {
                                    sw.Write(FileDelimiter);
                                }
                            }
                            sw.Write(sw.NewLine);
                        }

                        for (int ir = 0; ir < ColumnCount; ir++)
                        {
                            if (!Convert.IsDBNull(dr[ir]))
                            {
                                sw.Write(Escape(dr[ir].ToString()));
                            }
                            if (ir < ColumnCount - 1)
                            {
                                sw.Write(FileDelimiter);
                            }
                        }
                        if (rowno == TotRowsChunk)
                        {
                            sw.Close();
                            rowno = 1;
                            batchid = batchid + 1;

                            // SqlCommand data_cmdupd = new SqlCommand(data_query, myADONETConnection);
                        }
                        else
                        {
                            rowno = rowno + 1;

                            sw.Write(sw.NewLine);
                        }
                    }

                  
                    //   }
                    sw.Close();
                    
                    

                }
                data_cmd.Dispose();
                dr.Close();

                logQuery = " EXEC [ETL].[usp_BatchLog] @BatchID=0,@BatchStatus='In Progress',@TableName='" + TableName + " - Exporting to CSV',@TableStatus='Completed' ";
                data_cmdlog = new SqlCommand(logQuery, myADONETConnection);
                data_cmdlog.ExecuteNonQuery();

                data_cmdlog.Dispose();
                data_cmdlog.Dispose();
                Dts.TaskResult = (int)ScriptResults.Success;
            }

            catch (Exception exception)
            {
                if (dr != null)
                {
                    dr.Close();
                }

                string logQuery = " EXEC [ETL].[usp_BatchLog] @BatchID=0,@BatchStatus='In Progress',@TableName='Transactions - Exporting to CSV',@TableStatus='Error',@ErrorMessage='"+exception.Message.ToString()+"' ";
                SqlCommand data_cmdlog1 = new SqlCommand(logQuery, myADONETConnection);
                data_cmdlog1.ExecuteNonQuery();


                //// Create Log File for Errors
                //using (StreamWriter sw = File.CreateText("\\\\SVSFTP2K8001\\napier\\Log\\" +
                //    "ErrorLog_" + DateTime.Now.ToString() + ".log"))
                //{
                //    sw.WriteLine(exception.ToString());
                //    Dts.TaskResult = (int)ScriptResults.Failure;


                //}

                Dts.Events.FireError(-1, "Main()", exception.Message, "", -1);  // Raise the error event to SSIS,
                Dts.TaskResult = (int)ScriptResults.Failure; 
            }
            
            //try
            //{
            //    if (FileFullPath.Trim() != "")
            //    {
            //      //  System.IO.File.Copy(FileFullPath, "\\\\SVSFTP2K8001\\napier\\TEST\\" + Path.GetFileName(FileFullPath) + "", true);
            //    }
            //}
            //finally
            //{
            //}

            myADONETConnection.Close();
        }

        private static char[] quotedCharacters = { ',', '"', '\n' };
        private const string quote = "\"";
        private const string escapedQuote = "\"\"";

        private static string EncloseComma(string str)
        {
            return "\"" + str + "\"";
        }

        private static string Escape(string value)
        {
            //if (value == null) return "";
            //if (value.Contains(quote)) value = value.Replace(quote, escapedQuote);
            //if (value.IndexOfAny(quotedCharacters) > 1)
            value = quote + value + quote;
            return value;
        }

        private static string Unescape(string value)
        {
            if (value == null) return "";
            if (value.StartsWith(quote) && value.EndsWith(quote))
            {
                value = value.Substring(1, value.Length - 2);
                if (value.Contains(escapedQuote))
                    value = value.Replace(escapedQuote, quote);
            }
            return value;
        }
    }
}