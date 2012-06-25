
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
	<head><base href="http://www.usstudents.org:80/p.asp?WebPage_ID=107" />
	<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1"> 

	<title>Take Action Home</title>
	<!-- [/include/getRoot] -->
<!-- [/include/viewCheck] -->
<!-- [/include/isSecure] -->
<!-- [/include/formKit] -->
<!-- [/include/scripts] -->
<!-- [/include/formLink] -->

<script type="text/javascript">
	function checkLength( text, length){
		if(text.length > length)
			return false;
		return true;
	}
	
	function maxSize(message,text,length){
		if(!checkLength(text,length))
		{
			alert(message);
			text = text.substr(0,length);
			return text;
		}
		else{
			return text;
		}
	}

</script><!-- [/include/validate] -->

<SCRIPT type="text/javascript">

var arrMonths = new Array("January",
                          "February",
                          "March",
                          "April",
                          "May",
                          "June",
                          "July",
                          "August",
                          "September",
                          "October",
                          "November",
                          "December");


function validate(formName, isAffiliation)
{
	//the modified parameter isAffiliation is used so that it signifies
	//that an affiliation button is calling validate.  If this is the case,
	//kindly ignore all required affiliation buttons, since in order
	//to give them values, you must click on them.
	var DEBUG = false;
	if (DEBUG) alert("validate() called"); //DEBUG
	
	var s = "Please correct your errors as indicated:\n\n";
	var errMsg = "", fldName = "", fldValue = "", fldType = "", fldValue = "";
	var tmpArr, element = new Object();
	var myForm = document.forms[formName];
	var valid = true;
	var isReq = false;   // is this field required?
	var isEmpty = false;  // did the user enter anything?
	var reqErr = false;
	
	for (var i = 0; i < myForm.length; i++)
	{

		element = myForm.elements[i];
		fldName = String(element.name);
		
		fldValue = String(element.value);

		//alert(element.name + " "+element.type+" "+element.value+" " +element.options);

		
		if(String(fldValue) != 'null' && String(fldValue) != "")
		{
			fldValue = trim(fldValue)
			element.value = fldValue
		}

		// Check required fields for being empty
		isReq = Boolean(fldName.search("isReq")>=0);
		if( String(isAffiliation) != "undefined"){
			isReq = false
		}
		//alert("isReq found in "+fldName+" = "+isReq)
		isEmpty = Boolean(fldValue == "" || fldValue == "null");
		
		//This is a fix for checkboxes (Jeff 11.28.2001)
		if( element.type == "checkbox" ){ 
			isEmpty = Boolean(!element.checked); 
		}//if
		if( element.type == "select-one" &&  element.name.search("Affiliation") > -1 && element.options.length > 0){
			//alert(element.options.length);
			isEmpty = false;
		}//if		
		if(element.name.search("Affiliation") > -1 && String(isAffiliation) != "undefined"){
			isEmpty = false
		}
		if( element.type == "select-one" &&  element.name.search("Affiliation") == -1 && element.options.length > 0 ){
			//alert("isEmpty = "+isEmpty)
			if( element.selectedIndex != -1 ) {
				selectedOption = element.options[element.selectedIndex]
				selectedOptionValue = String(selectedOption.value)
				//alert(element.name+" has a selected option value of "+selectedOptionValue)
				if(selectedOptionValue == "" || selectedOptionValue == "null" || selectedOptionValue=="undefined"){
					//alert("selectedOptionValue = blank or null its value is "+selectedOptionValue)
					isEmpty = true
				}	
				else{
					isEmpty = false
				}					
			}
			else{
				//alert("selectedIndex = -1, therefore nothing has been selected")
				isEmpty = true
			}	
			//alert("isEmpty = "+isEmpty)		
		}//if		
		if( element.type == "radio"){
			radioNotChecked = true
			radioName = String(fldName)
			while(element.type == "radio" && element.name == radioName){
				//loop through and examine each and every radio button of this name
				//to determine if any are checked						
				radioNotChecked = radioNotChecked && Boolean(!element.checked)
				i++
				element = myForm.elements[i];
				fldName = String(element.name);		
			}//while
			isEmpty = radioNotChecked
			i--
			element = myForm.elements[i];
			fldName = String(element.name);					
		}
		
		//alert("isEmpty = "+isEmpty+" and isReq="+isReq)
		reqErr = Boolean(isReq && isEmpty);
		//alert("reqErr = "+reqErr)
		
		if (reqErr) // required and empty
		{
			//alert(element.name + "must have an entry and it's type is"+ element.type)
			var tempMsg = element.id + " must have an entry\n";
			//This is a fix for checkboxes (Jeff 11.28.2001)			
			if( element.type == "checkbox" ){ 
				tempMsg = element.id + " must be checked\n"; 
			}//if
			
			s += tempMsg
			valid = false;
		}
		else
		{
			tmpArr = fldName.split(".");
			if (tmpArr.length > 2)  // if this field has a special field type
			{

			//alert("fldName is '"+fldName+"'"); //DEBUG
			
				fldType = tmpArr[2];
				
				//if(DEBUG && Boolean(fldName.indexOf("Date")+1)){
				if(DEBUG && (fldType == "Time" || fldType == "Date" || fldType == "Number" 
						|| fldType == "Currency" || fldType == "email")) {
					if(!(confirm("field name="+fldName+", value="+fldValue+", label="+element.id
								+"\n isReq="+isReq+", isEmpty="+isEmpty+", reqErr="+reqErr+", valid="+valid
								+"\n error message so far = \n"+s
								+"\n\nDo you want to continue?"))){
						return false;
					}
				}

				switch (fldType) 
				{ 
					case "Time" :
						if (DEBUG) alert("checking time entry"); 
						errMsg = validTime(element);
						if (errMsg.length > 0)
						{
							valid = false;
							s += errMsg + "\n"
						} 
						break;
					case "Date" :
						if (DEBUG) alert("checking date entry"); 
						errMsg = validDate(element);
						if (errMsg.length > 0)
						{
							valid = false;
							s += errMsg + "\n"
						} 
						break;
					case "Number" :
						if (DEBUG) alert("checking number entry"); 
						errMsg = validNumber(element);
						if (errMsg.length > 0)
						{
							valid = false;
							s += errMsg + "\n"
						} 
						break;
					case "Currency" :
						if (DEBUG) alert("checking currency entry"); 
						errMsg = validCurrency(element);
						if (errMsg.length > 0)
						{
							valid = false;
							s += errMsg + "\n"
						} 
						break;
					case "email" :
						if (DEBUG) alert("checking email entry"); 
						errMsg = validEmail(element);
						if (errMsg.length > 0)
						{
							valid = false;
							s += errMsg + "\n"
						} 
						break;
				}// end switch on field type
			}// if this field has a special field type
		} // if else an empty required field
	}// end for each element in the form
	//alert("meet a: "+a)
	//alert("valid="+valid)
	//alert("s = "+s)
	if (!valid){
		if( s.search(/undefined/i) == -1){
			alert(s);  // Pop up error messages
		}
		else{
			alert("Please fill in all required fields and ensure you have entered information in the correct format.")
		}	
	}	
	return valid;

}

/*******************************************************************************
    VALIDATE A TIME ENTRY
    Takes a form element (an INPUT 'object')
    Returns an error message (empty string means no error)
*/
function validTime(element)
	{
	var err = "";
	var msgUnkErr  = "Enter a valid time hh:mm (am|pm)"
	var msgHours   = "Valid Hours are 0-23"
	var msgMinutes = "Valid Minutes are 1-59";
	var val = new String(element.value);  // Get user input
	//alert("val="+val); // DEBUG	
	// if no user input, skip time checking
	if (String(val) != "" && String(val) != 'undefined')
	{
		var hrs =0, mins = 0;
		var valid = true;
		var str0="", str1="", str2="";
		
		
		val = val.replace(/[\. ]/g,"");  //strip out any periods and spaces
		
		//check for only valid characters and no more than 2 alpha characters
		valid = Boolean(val.search(/[^apm:\d]/ig)==-1 && val.search(/[a-z]{3,}/i)==-1);
		//alert("valid="+valid); //DEBUG
		//alert("not valid character found at "+val.search(/[^\d:apm]/ig)); //DEBUG

		// This breaks up the input into an array of hours, minutes and am/pm
	
		results = val.match(/^[12]?\d:|\d{1,2}| *[pa]m?$/ig);
		
		//alert("parsed entry is "+String(results)+ "\nlength is "+results.length
		//			+"\nValid is "+valid); //DEBUG
		
		// if user didn't put in anything recognizable as a time,
		// skip parsing and processing it
		if(results==null || !valid)
		{
			err = element.id +" - " + msgUnkErr;
			valid = false;
		}
		else
		{
			for (var i = 0; i < results.length; i++)
			{
				//alert("resutls[i]="+results[i]); // DEBUG
				// format am/pm: [space][A|P]M
				if(results[i].search(/^[ap]/i)>-1) { results[i] = " "+ results[i].toUpperCase(); }  // if no leading space, add one
				if(results[i].search(/[ap]$/i)>-1) { results[i] = results[i] + "M"; } // if no trailing M, add one
				if(results[i].search(/a-z/i)>-1 && !(results[i] == "AM" || results[i] == "PM"))
				{
					results[i]="ERR"
				}
				eval("var str"+i+" = results[i]");  //save part (hours, minutes or am/pm) to variables
				
				//alert("resutls[i]="+results[i]); // DEBUG
			}
			
			// paste parts together again
			val = new String(str0+str1+str2) 
			
			// attempt to make a date object from it
			var myTime = new Date(Date.parse('01/01/1970 '+val)); // 01/01/1970 is default date for SQL Server
			
			//alert("myTime is "+typeof(myTime)); //DEBUG
			
			// If date object creation failed, try to fix it.
			if (isNaN(myTime))
			{
				var numOfParts = results.length;
				
				if (numOfParts > 0)
				{
					// first part should be hours
					if ((str0).search(/:/)>-1)
					{
						hrs = parseInt(str0.replace(/:/,""), 10); //strip off the colon for parsing
					}
					else
					{
						hrs = parseInt(str0, 10);
						//alert("hrs="+hrs); //DEBUG
					}
					if (isNaN(hrs))
					{
						err = element.id +" - " + msgUnkErr;
						valid = false
					}
					else
					{
						if (hrs > 23 || hrs <0 )
						{
							err = element.id +" - " + msgHours;
							valid = false;
						}
						else
						// add a colon to hours
						{
							str0 = String(hrs)+":";
						}
					}// is (not) a number
					
					// second part should be minutes, or am/pm 
					// (don't bother with this check if an error already encountered)
					if (valid && numOfParts > 1)
					{
						mins = parseInt(str1,10);
						
						// if user entered non-numeric (even am or pm)...
						if (isNaN(mins))
						{
							if ( (str1.search( /^ AM$/)== -1) && (str1.search( /^ PM$/)== -1) )
							{
								err = element.id +" - " + msgUnkErr;
								valid = false;
							}
							if (valid && hrs > 12)
							{
								str1 = "";  // don't want AM or PM with 24-clock hours
							}
						}
						// only allow 1-59 to be entered for minutes
						else 
						{
							if (mins > 59 || mins <0)
							{
								err = element.id +" - " + msgMinutes;
								valid = false;
							}
						}// if isNaN(mins)
					}// num of parts > 1
				}// num of parts > 0
				
				// paste parts together again
				val = new String(str0+str1+str2)
				myTime = new Date(Date.parse('01/01/1970 '+val)); // 01/01/1970 is default date for SQL Server
				if (isNaN(myTime))
				{
					err = element.id +" - " + msgUnkErr;
					valid = false;
				}
			}// if there was an error
		}// if (no) results from parsing
		if (valid)
		{
			val = new String((myTime.toString()).slice(10,15));
			element.value = val;
		}
	} //is val is undefined
	return err;
}// function validTime

/*******************************************************************************
    VALIDATE A DATE ENTRY
    Takes a form element (an INPUT 'object')
    Returns an error message (empty string means no error)
    If no year entered, the default is this year
*/
function validDate(element)
{
	var err = "";
	var msgUnkErr  = "Enter a valid date mm/dd/yy(yy)"
	var msgMonth   = "Valid Months are 1-12"
	var msgDay = "Valid Days for ";  // append range based on month
	var strMnth = "";
	var myDate;
	var mnth =0, day = 0, year =0;
	var valid = true;
	var str0="", str1="", str2="";
	var val = new String(element.value);  // Get user input
	

	
	// if no user input, skip date checking
	if (String(val) != "" && String(val) != 'undefined')
	{
		
		var test = val.search(/[^0-9\/]/ig);
		//alert("test is "+String(test)); //DEBUG
		
		// if user didn't put in anything recognizable as a date,
		// skip parsing and processing it
		if(val.indexOf("/")== -1 || val.search(/[^0-9\/g]/i) != -1)
		{
			err = element.id +" - " + msgUnkErr;
			valid = false;
		}

		if( val.length < 6){
			err = element.id +" - " + msgUnkErr;
			valid = false;	
		}

			
		if (valid) // it passed the "/"  and no alpha's test
		{
			// This breaks up the input into an array of month, day, year
			var results = val.split("/");
			
			for (var i = 0; i < results.length; i++)
			{
				eval("var str"+i+" = results[i]");  //save part (month, day or year) to variables
			}
			
			var numOfParts = results.length;
			
			if (numOfParts < 2)
			{
				err = element.id +" - " + msgUnkErr;
				valid = false;
			}
			
			if (valid)
			{
				//alert("year entered is "+str2);  //DEBUG
				// Get the year
				var len2 = str2.length

				if (len2 != 0)
				{
					if (len2 == 2 || len2 == 4)
					{
						myDate = new Date("1/1/"+str2);
					}
					else
					{
						err = element.id +" - " + msgUnkErr;
						valid = false;
					}				
				}
				else
				{
					myDate = new Date();
					//alert("today is "+myDate.toString());  //DEBUG
				}
			}// valid?
				
				if (valid)
				{
				if (len2 == 4 || len2 == 0)
				{
					year = myDate.getFullYear();
				}
				else
				{
					year = parseInt(str2,10); 
				
					// because getFullYear converts 01 to 1901
					if (year >= 0 && year< 50)
					{
						year += 2000
				}
					else if (year >= 50 && year <100)
					{
						year += 1900
					}
				}// 4 digit vs 2 digit year
			}// valid?
				
			//alert("year is "+String(year));  //DEBUG
			//alert("year is "+String(year));  //DEBUG
		
		// if this is a valid year		
		if (valid)
		{
				// first part should be a month number
				mnth = parseInt(str0,10);
				//alert("Entry is "+str0+", month is "+String(mnth));  //DEBUG
				if (isNaN(mnth))
				{
					err = element.id +" - " + msgUnkErr;
					valid = false;
				}
				else
				{
					//alert("mnth is a number");  //DEBUG
					if (mnth > 12 || mnth <1 )
					{
					err = element.id +" - " + msgMonth;
					valid = false;
					}
				}// is (not) a number
				
				// second part should be the day number 
				// (don't bother with this check if an error already encountered)
				if (valid && numOfParts > 1)
				{
					day = parseInt(str1, 10);
					
					// if user entered non-numeric (even am or pm)...
					if (isNaN(day))
					{
						err = element.id +" - " + msgUnkErr;
						valid = false;
					}
					// only allow 1-[28-31] to be entered for months
					else 
					{
						switch (mnth) 
						{ 
						   case 1 :
						   case 3 :
						   case 5 :
						   case 7 :
						   case 8 :
						   case 10 :
						   case 12 :
									//alert("A month with 31 days"); //DEBUG
						      if(day > 31)
						      {
										strMnth = arrMonths[mnth-1];
										err = element.id +" - " + msgDay + strMnth + " are 1-31";
										valid = false; 
									}
						      break; 
						   case 4 :
						   case 6 :
						   case 9 :
						   case 11 : 
									//alert("A month with 30 days"); //DEBUG
						      if(day > 30)
						      {
										strMnth = arrMonths[mnth-1];
										err = element.id +" - " + msgDay + strMnth + " are 1-30"; 
										valid = false; 
									}
						      break; 
						   case 2 : 
						      if (day > 28)
						      {
										// figure out if "year" is a leap year; don't forget that
										// century years are only leap years if divisible by 400
										
										var isleap=((year%4==0 && year%100!=0) || year%400==0);
										
										/*alert ("year%4==0 is "+String(year%4==0)
														+"\nyear%100!=0 is "+String(year%100!=0)
														+"\nyear%400==0 is "+String(year%400==0)
														);  //DEBUG */
										//alert ("leap year is "+String(isleap));  //DEBUG
										
										strMnth = arrMonths[mnth-1];
										
										if (isleap )
										{
											if (day > 29)
											{
												err = element.id +" - " + msgDay + strMnth + " in a leap year are 1-29"
												valid = false; 
											}
										}
										// Not leap year
										else
										{
											err = element.id +" - " + msgDay + strMnth + " are 1-28"; 
											valid = false; 
										}
									}
						      break;
						    default:
										//alert(String(mnth)+" was not processed");  //DEBUG
						 }// end switch
					}// if isNaN(day)
				}// num of parts > 1
			}// num of parts > 0
		}// if contains "/"	
		if (valid)
		{
			val = String(mnth) + "/" + String(day) + "/" + String(year)
			//alert("new value is "+val); //DEBUG
			element.value = val;
		}
	} //is val is undefined
	return err;
}// function validDate

/*******************************************************************************
    VALIDATE A NUMBER ENTRY
    Takes a form element (an INPUT 'object')
    Returns an error message (empty string means no error)
*/
function validNumber(element)
{
	var err = "";
	var msgNaNErr  = "Enter a valid number (only numbers, and properly placed minus sign, commas, and decimal points)"
	var valid = true;
	var val = new String(element.value);  // Get user input
	
	// if no user input, skip number checking
	if (String(val) != "" && String(val) != 'undefined')
	{
		var test = val.search(/[^0-9\-\,\.]/ig);
		//alert("test is "+String(test));  //DEBUG
		
		// if user didn't put in anything recognizable as a number,
		// skip parsing and processing it
		if(test != -1)
		{
			err = element.id +" - " + msgNaNErr;
			valid = false;
		}
			
		if (valid) // it passed acceptable characters test
		{
			val = val.replace(/,/g,""); //strip out commas
			if ( isNaN(val) )
			{
				err = element.id +" - " + msgNaNErr;
				valid = false;
			}
			decimalAndToRight = ""
			if(val.indexOf(".") != -1){
				//there is a decimal point.  remove it and all to right then add
				//commas then add them back in again...
				decimalAndToRight = val.substring(val.indexOf("."),val.length)
				val = val.substring(0,val.indexOf("."))
			}
			//this now adds commas
			val = addCommas(val)
			val += decimalAndToRight			
			element.value = val
		}// passed acceptable characters test	
	} //is val is undefined
	return err;
}// function validNumber


/*******************************************************************************
    VALIDATE A CURRENCY ENTRY
    Takes a form element (an INPUT 'object')
    Returns an error message (empty string means no error)
*/
function validCurrency(element)
{
	var err = "";
	var msgNaNErr  = "Enter a valid currency (only numbers, and properly placed minus sign, commas, and decimal points)"
	var valid = true;
	var val = new String(element.value);  // Get user input
	
	// if no user input, skip currency checking
	if (String(val) != "" && String(val) != 'undefined')
	{
		var test = val.search(/[^0-9\$\-\,\.]/ig);
		//alert("[validCurrency] test (for illegal chars) is "+String(test)+" for "+element.id+" with value of "+val);//DEBUG	
		
		// if user didn't put in anything recognizable as a currency,
		// skip parsing and processing it
		if(test != -1)
		{
			err = element.id +" - " + msgNaNErr;
			valid = false;
		}
			
		if (valid) // it passed acceptable characters test
		{
			val = val.replace(/[,\$]/g,"")  //strip out commas & dollar signs		
			
			if(val.indexOf(".") == -1){
				//there is no '.' in the string, put one in
				val = val + ".00"
			}				
			else if(val.length - val.indexOf(".") == 2){
				val = val + "0"
			}	
			else{
				val = val.substring(0, val.indexOf(".")+3)
			}
			if ( isNaN(val) )
			{
				err = element.id +" - " + msgNaNErr;
				valid = false;
			}
			val = addCurrency(val)			
			element.value = val
		}// passed acceptable characters test	
	} //is val is undefined
	return err;
}// function validCurrency

/*******************************************************************************
    VALIDATE A EMAIL ENTRY
    Takes a form element (an INPUT 'object')
    Returns an error message (empty string means no error)
*/
function validEmail(element)
{	
	var err = "";
	var msgEmailErr  = "Enter a valid email address (user@domain[.subdomain ...].ext)"
	//var regXemail = "^[\\w-\|\'\\.]*[\\w-]+\\@[\\w-]+(\\.[\\w-|']+)*\\.[a-z]{2,3}$";
	//var regex = new RegExp(regXemail, "i");
	var regex = /^([a-zA-Z0-9_\-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/i
	var valid = true;
	var val = new String(element.value);  // Get user input
	
	// if no user input, skip currency checking
	if (String(val) != "" && String(val) != 'undefined')
	{
    valid = regex.test(val);

		if (!valid) // it failed acceptable characters test
		{
			err = element.id +" - " + msgEmailErr;
			//alert("[validEmail] failed validation for "+element.id); //DEBUG
		}
	} //is val is undefined
	return err;
}// function validCurrency


/*******************************************************************************
    TRIM A STRING
    Strips off all leading and trailing spaces
    Takes a string
    Returns a string
*/
function trim(val)
{
	var len = val.length;
	
	//RTRIM
	while(val.charAt(len-1) == ' ')
	{
		len = len-1;
		val = val.substr(0,len);
	}
	//LTRIM
	while(val.charAt(0) == ' ')
	{
		val = val.substr(1);
	}
	return val;
}//end function trim

function addCurrency( strValue ) {
/************************************************
DESCRIPTION: Formats a number as currency.

PARAMETERS: 
  strValue - Source string to be formatted

REMARKS: Assumes number passed is a valid 
  numeric value in the rounded to 2 decimal 
  places.  If not, returns original value.
*************************************************/
  var objRegExp = /-?[0-9]+\.[0-9]{2}$/;
  
  
//'   /(-?[0-9]+)(\.[0-9]{1,5})?$/
    if( objRegExp.test(strValue)) {
      objRegExp.compile('^-');
      var negSign = '';
      strValue = addCommas(strValue);
      if (objRegExp.test(strValue)){
        strValue = strValue.replace(objRegExp,'');
        negSign = '-';
      }
      return negSign + '$' + strValue;
      
    }
    else{
      return strValue;
     }
}

function addCommas( strValue ) {
/************************************************
DESCRIPTION: Inserts commas into numeric string.

PARAMETERS: 
  strValue - source string containing commas.
  
RETURNS: String modified with comma grouping if
  source was all numeric, otherwise source is 
  returned.
  
REMARKS: Used with integers or numbers with
  2 or less decimal places.
*************************************************/
  var objRegExp  = new RegExp('(-?[0-9]+)([0-9]{3})'); 

    //check for match to search criteria
    while(objRegExp.test(strValue)) {
       //replace original string with first group match, 
       //a comma, then second group match
       strValue = strValue.replace(objRegExp, '$1,$2');
    }
  return strValue;
}





</SCRIPT>

<!-- /include/webFunctions -->

 
<meta NAME="Keywords" CONTENT="higher education, HEA Reauthorization, appropriations, advocacy, change, non-profit, 501(c)(3), donate, news, student power, grassroots, organizing, student lobby, lobbying, US Capitol, Capitol Building, LegCon, Congress, USSA, national student association, united states student association, student association, financial aid, loan consolidation, students of color, diversity, LGBT students, elections, electoral training, State Student Association, SSA, ">
<!-- [tools/executeSearch] -->
<!-- [/include/scripts] -->

<!-- [tools/Profile/searchProfileForm] -->
<!-- [/include/scripts] -->
<!-- /tools/Profile/displayProfiles -->
<!-- [/tools/Profile/editProfile] -->



<SCRIPT type="text/javaScript">

	function openAffiliationLink(newWebPageId, formName, selectName){
		var currDD = document.forms[formName].elements[selectName];
		var currProf =  currDD.selectedIndex;
		if(currDD.selectedIndex != -1){
			if(currDD.options[currProf] != null){
				selectedProfile = currDD.options[currProf].value;			
				if(selectedProfile != "" && selectedProfile != "undefined" && newWebPageId != ""){
					window.open("../../p.asp?WebPage_ID="+newWebPageId+"&Profile_ID="+selectedProfile,selectedProfile,"resizable=yes,scrollbars=yes,menubar=no,width=800,height=600")
					//null,"width=800,height=600"
				}
				else{
					alert("There is no page defined for this function. Configure at the 'Field' level for this profile add/edit.")
				}
			}
			else{
				alert("Double clicking in the scrolling portion of the select box is not supported in this browser.")
			}
		}//end if
	}//end function



function addAffToNew(id,name,currentFormName, webProfileFieldId ){	
	currentForm = document.forms[currentFormName]
	currentForm.elements["popup.FieldName_ID"].value=id
	currentForm.elements["popup.webProfileField_ID"].value=webProfileFieldId
	currentForm.elements["popup.fieldName"].value=name
	currentForm.elements["popup.page_ID"].value=107
	currentForm.submit();
}


function BreakItUp(theForm)
{
  //Set the limit for field size.
  var FormLimit = 102399
	currentForm = document[theForm.name];
  for(var i=0;i<currentForm.length;i++){
		currentElement =currentForm.elements[i];
		if(currentElement.type == "textarea")
			{
			//Get the value of the large input object.
			var TempVar = new String
			TempVar = currentElement.value

			//If the length of the object is greater than the limit, break it
			//into multiple objects.
			if (TempVar.length > FormLimit)
			{
			  currentElement.value = TempVar.substr(0, FormLimit)
			  TempVar = TempVar.substr(FormLimit)

			  while (TempVar.length > 0)
			  {
			    var objTEXTAREA = document.createElement("TEXTAREA")
			    objTEXTAREA.name = currentElement.name
			    objTEXTAREA.value = TempVar.substr(0, FormLimit)
			    currentForm.appendChild(objTEXTAREA)
			    TempVar = TempVar.substr(FormLimit)
			  }

			}
		}
	}
}

function makeAffSelected(){
	//this function goes through the entire form array and 
	//makes sure that all affiliation select boxes have all their
	//options selected.
	for(var i=0;i<document.forms[0].elements.length;i++){
		formElement = document.forms[0].elements[i]
		formElementName = String(formElement.name);
		if(formElementName.indexOf(".Affiliation") != -1){
			//this is an affiliation type go through all it's options and select them
			for(var j=0;j<formElement.options.length;j++){
				formElement.options[j].selected = true;
			}//for			
		}//end if		
	}//for	
	return(true);	
}//function
</SCRIPT>


</head>
<link rel="stylesheet" href="ussaDir/files/documents/css/global.css" type="text/css">





<body>

<style type="text/css">
<!--
a:link, a:active, a:visited {
	color: #0F0EA7;
	text-decoration: none;
}
a:hover {
	color: #1E8CC1;
	text-decoration: underline;
}
body {
	margin: 0px;
	padding: 0px;

	background: #1A6386 url(background.jpg);
}
#mainnav {
	border-right: 1px solid #B6B7A9;
	border-left: 1px solid #B6B7A9;
	padding: 5px 10px 5px 15px;
	color: #555555;
	font: bold 80%/20px Verdana, Arial, Helvetica, sans-serif;
}

#rightcolumn {
	padding: 7px;
	border-right: 1px solid #B6B7A9;
	border-left: 1px solid #B6B7A9;
	color: #666666;
	font: bold 80%/20px Verdana, Arial, Helvetica, sans-serif;
}
.verdana9 {
	font: normal 70%/12px Verdana, Arial, Helvetica, sans-serif;
	letter-spacing: normal;
}
#headerbottomrow {
	border-top: 1px #B6B7A9;
	border-right: 1px solid #B6B7A9;
	border-bottom: 1px solid #B6B7A9;
	border-left: 1px solid #B6B7A9;
}
#headerbottomrowleft {
	border-bottom: 1px solid #B6B7A9;
	border-left: 1px solid #B6B7A9;
}
#headerbottomrowright {
	border-right: 1px solid #B6B7A9;
	border-bottom: 1px solid #B6B7A9;
}
.headline {
	font: bold 18px Arial, Helvetica, sans-serif;
	color: #4E4E4E;
}
#centercolumn, #centercolumn td {
	font: 70% Verdana, Arial, Helvetica, sans-serif;
	color: #535353;
  padding-left: 4px;
  padding-right: 4px;
  
}
input {
	color: #333333;
	font: 10px Verdana, Arial, Helvetica, sans-serif;
}
.footerrow {
	border-top: 1px solid #B6B7A9;
}
.sectiontitle {
	font: bold 210% Arial, Helvetica, sans-serif;
	color: #0F0EA7;
	letter-spacing: -1.5px;
	text-transform: capitalize;
	width: 100%;
	border-bottom: 1px solid #CCCCCC;
	margin-bottom: 2px;
	padding-bottom: 2px;
}
.verdana12 {
	font: 12px Verdana, Arial, Helvetica, sans-serif;
}
#sectionnav {
	font: 70% Verdana, Arial, Helvetica, sans-serif;

	padding: 0px 0px 0px 0px;
	margin: 0px 0px 0px 0px;
	color: #666666;
	border-top: 1px none #B6B7A9;
	border-right: 1px solid #B6B7A9;
	border-bottom: 1px solid #B6B7A9;
	border-left: 1px solid #B6B7A9;
}
.grouptitle {
	font: bold 220% Arial, Helvetica, sans-serif;
	color: #0F0EA7;
	letter-spacing: -1.5px;
	text-transform: capitalize;
}
.mediumarial {
	font: bold 120% Arial, Helvetica, sans-serif;
	color: #777;
}
-->
</style>






<table width="760" border="0" align="center" cellpadding="0" cellspacing="0">
  <tr>
    <td><p><a href="/"><img src="ussaDir/template/5headerk.jpg" width="760" height="133" border=0></a></p>
    </td>

  </tr>
</table>

<table width="760" border="0" align="center" cellpadding="0" cellspacing="0"><tbody>
  <tr bgcolor="#EFEFE7" ><td  align="center" valign="middle" bgcolor="#FFFFFF"  id="sectionnav" height="15"> <br><!--  This code is for the top level nav menu item, in order for it to work properly, it must be the first item in the content -->
<!-- [/include/webFunctions.asp]doWebMenu(rs) -->
	<!-- start menu-->	<a  href='p.asp?WebPage_ID=16'  ><b>About USSA</b></a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=105'  ><b>Legislative</b></a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=86'  ><b>Trainings</b></a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=165'  ><b>Action Center</b></a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=134'  ><b>Conferences</b></a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=106'  ><b>USSA Foundation</b></a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=23'  ><b>News</b></a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=37'  ><b>Events</b></a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=169'  ><b>Support</b></a>&nbsp;	<!-- end menu--><br/><br/></td>
</tbody>
</table>
<table width="760" border="0" align="center" cellpadding="0" cellspacing="0">
  <tr>
    <td width="150" background="ussaDir/template/lightbg.gif" id="mainnav" valign="top">
      
<!-- [/include/webFunctions.asp]doWebMenu(rs) -->
<!--EMPTY MENU--> 

<hr size="1">
<img src="ussaDir/files/images/filmstrip06.jpg">
<!--<a class=mediumarial href="http://www.usstudents.org/p.asp?WebPage_ID=106">Foundation Projects</a><br>
<br>
<img src="ussaDir/files/images/arrow.gif"> <a href="http://www.usstudents.org/p.asp?WebPage_ID=86">Trainings</a><br>
<span class=verdana9>
USSA Foundation has developed two trainings to build skills of campus leaders and increase student power: The Electoral Action Training (EAT) and the GrassRoots Organizing Weekend (GROW).
</span><br>
<br>
<img src="ussaDir/files/images/arrow.gif"> <a href="http://www.usstudents.org/p.asp?WebPage_ID=106">Students of Color</a><br>
<span class=verdana9>
The Student of Color Campus Diversity Project provides students with education materials, organizing training, leadership development, and networking opportunities to help students win victories to increase student of color recruitment and retention on campus.
</span><br>
<BR>
<img src="ussaDir/files/images/arrow.gif"> <a href="http://www.usstudents.org/p.asp?WebPage_ID=106">LGBT Students</a><br>
<span class=verdana9>
Lesbian, Gay, Bisexual, and Transgender (LGBT) Student Empowerment Project provides students with education materials, organizing training, leadership development, and networking opportunities to make their campuses more hospitable places for LGBT students to live and learn.
</span><br>
<br>
<img src="ussaDir/files/images/arrow.gif"> <a href="http://www.usstudents.org/p.asp?WebPage_ID=106">Students & Labor</a><br>
<span class=verdana9>The Student Labor Action Project provides student activists with the tools they need to become the backbone of campus and community campaigns on a wide range of workers’ rights and economic justice issues.
</span><br>-->
<br>
 </td>
    <td valign="top" bgcolor="#FFFFFF" id="centercolumn">



<table border=0  width=100% cellspacing=0 cellpadding=0 align=center >
 
<!--murr1pageOpenRow-->
<tr ><td  align=center   valign=top><IMG border="0" alt="spacer" src="images/adminimages/blank.gif" height="15" width="1"></td></tr>
<!--murr2end pageCloseRow-->

<!--murr3pageOpenRow-->
    <tr >
     <td  align=center   valign=top>
      <table border=0 cellspacing=0 cellpadding=0 background="">
       <tr align=center>
<!--end pageOpenRow-->

<!--pageopenTableCell-->
        <td align=center><table border=0 cellspacing=0 cellpadding=0 >
          <tr>
           <td align=center  >
<!--end pageopenTableCell-->

<!-- [/include/webFunctions.asp]doWebMenu(rs) -->
	<!-- start menu-->	<div style="border-style:solid;border-width:1px 0px 1px 0px;border-color: #cccccc;background:#f0f0f0;padding:2px;">Take Action Center</div><a  href='p.asp?WebPage_ID=107'  >Take Action Home</a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=142'  >FY07 Appropriations</a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=143'  >HEA Reauthorization</a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=44'  >Action Alerts</a>&nbsp;|&nbsp;<a  href='p.asp?WebPage_ID=114'  >Contact Congress</a>&nbsp;	<!-- end menu-->
<!--pagecloseTableCell-->
</font></td>
          </tr>
         </table></td>
<!--end pagecloseTableCell-->

<!--murr4pagecloseRow-->
		</tr>
	 </table></td>
 </tr>
<!--end pageCloseRow-->

<!--murr1pageOpenRow-->
<tr ><td     valign=top><IMG border="0" alt="spacer" src="images/adminimages/blank.gif" height="15" width="1"></td></tr>
<!--murr2end pageCloseRow-->

<!--murr3pageOpenRow-->
    <tr >
     <td  align=center   valign=top>
      <table border=0 cellspacing=0 cellpadding=0 background="">
       <tr align=center>
<!--end pageOpenRow-->

<!--pageopenTableCell-->
        <td align=center><table border=0 cellspacing=0 cellpadding=0 >
          <tr>
           <td align=center  ><font  size=4 color='red'>
<!--end pageopenTableCell-->
Welcome to the Take Action Center!<br>Organize, Mobilize, and Win!
<!--pagecloseTableCell-->
</font></td>
          </tr>
         </table></td>
<!--end pagecloseTableCell-->

<!--murr4pagecloseRow-->
		</tr>
	 </table></td>
 </tr>
<!--end pageCloseRow-->

<!--murr1pageOpenRow-->
<tr ><td     valign=top><IMG border="0" alt="spacer" src="images/adminimages/blank.gif" height="25" width="1"></td></tr>
<!--murr2end pageCloseRow-->

<!--murr3pageOpenRow-->
    <tr >
     <td     valign=top>
      <table border=0 cellspacing=0 cellpadding=0 background="">
       <tr >
<!--end pageOpenRow-->

<!--pageopenTableCell-->
        <td ><table border=0 cellspacing=0 cellpadding=0 >
          <tr>
           <td   ><font  size=2>
<!--end pageopenTableCell-->
Here you will find information on USSA's National Campaigns and ways you can join the fight to make education a right!  You can download our organizing packets and factsheets to educate and mobilize your campus to effect federal issues impacting students. Just click on the campaign you are interested in and you will learn how you can TAKE ACTION!
<p>
USSA tracks and lobbies federal legislation and policy, and organizes students from across the country to participate in the political process, through testifying in official Congressional hearings, letter-writing campaigns, and face-to-face lobby visits between students and their elected officials.
<p>
If you have additional questions, please contact our Organizing Director, Jessica Pierce, at od@usstudents.org   
<p>
Please also visit our Legislative Department to learn about key Congressional Committees, how bills become law, our higher education coalition work, and search for your congressional member.

  

<!--pagecloseTableCell-->
</font></td>
          </tr>
         </table></td>
<!--end pagecloseTableCell-->

<!--murr4pagecloseRow-->
		</tr>
	 </table></td>
 </tr>
<!--end pageCloseRow-->

<!--murr1pageOpenRow-->
<tr ><td     valign=top><IMG border="0" alt="spacer" src="images/adminimages/blank.gif" height="25" width="1"></td></tr>
<!--murr2end pageCloseRow-->

<!--murr3pageOpenRow-->
    <tr >
     <td     valign=top>
      <table border=0 cellspacing=0 cellpadding=0 background="">
       <tr >
<!--end pageOpenRow-->

<!--pageopenTableCell-->
        <td ><table border=0 cellspacing=0 cellpadding=0 >
          <tr>
           <td   >
<!--end pageopenTableCell-->

<!-- [/include/webFunctions.asp]doWebMenu(rs) -->

			<script>
				//alert("rememberPageURL = true")
				var pageUrl = window.document.location;				
				pageUrl = escape(pageUrl);
				window.open("../tools/createSessionVariable.asp?sessionName=rememberedURL&sessionValue="+pageUrl, null, "top=40000,height=100,width=100");
			</script>
		<!-- start menu-->	<BR><a target=_blank href='p.asp?WebPage_ID=62'  >Tell A Friend!</a> (new window)<BR><br />	<!-- end menu-->
<!--pagecloseTableCell-->
</font></td>
          </tr>
         </table></td>
<!--end pagecloseTableCell-->

<!--murr4pagecloseRow-->
		</tr>
	 </table></td>
 </tr>
<!--end pageCloseRow-->
</table>	
<td width="150" valign="top" background="ussaDir/template/lightbg.gif" id="rightcolumn">      <label for="label2"></label>      <span class="verdana9"><br>
          <br>

      </span>      <hr size="1">    <span class="mediumarial">  
    
     <center><a href="http://www.usstudents.org/p.asp?WebPage_ID=165"><img src="ussaDir\files\images\buttons\HEA.jpg"></a></center>
<br>
<center><a href="http://studentlabor.org"><img src="http://www.usstudents.org/ussaDir/files/images/buttons/Week.JPG"></a.</center>
<br>
<center><a href="http://www.DAYOFSILENCE.ORG"><img src="ussaDir\files\images\buttons\dayofsilence.JPG"></a></center>
<br>
<center><a href="http://www.usstudents.org/p.asp?WebPage_ID=134"><img src="ussaDir\files\images\buttons\60thCongress.jpg"></a></center>
<br>
<center><a href="http://www.usstudents.org/p.asp?WebPage_ID=163"><img src="ussaDir\files\images\buttons\ivotebutton.jpg"></a></center>
<br>
<center><a href="http://www.usstudents.org/p.asp?WebPage_ID=26"><img src="ussaDir\files\images\buttons\ussaupdate.jpg"></a></center>
<br>
<center><a href="http://www.usstudents.org/p.asp?WebPage_ID=21"><img src="ussaDir\files\images\buttons\jobannouncements.jpg"></a></center>
<br>
<center><a href="http://www.usstudents.org/p.asp?WebPage_ID=169"><img src="ussaDir\files\images\buttons\Donate.JPG"></a></center>
<br>

    
    
    
    
    
    
    
    
    
      </span>

      <div align="center"><br>
        <img src="ussaDir/template/fistperson.gif" width="118" height="300"></div></td>
  </tr>
</table>
<table width="760" border="0" align="center" cellpadding="0" cellspacing="0">
  <tr bgcolor="#EFEFE7">
    <td colspan="3" align="center" valign="top" bgcolor="#FFFFFF" class="footerrow" id="mainnav"><img src="ussaDir/template/footerorganizing.gif" alt="Organizing and Advocating Since 1947" width="251" height="11" vspace="4"><br>

        <span class="verdana9"><strong>United States Student Association | <a href="mailto:ussa@usstudents.org">ussa@usstudents.org</a></strong><br>
      815 16th Street NW, 4th Floor - Washington, DC 20006<br>
      (202) 637-3924 (phone) | (202) 637-3931(fax)<br>
      <br>
&copy; 2003 United States Student Association, all rights reserved. | <a href="#">Acceptable
Use</a> | <a href="#">Powered by NetCorps</a></span></td>

  </tr>
</table>





<!--
     FILE ARCHIVED ON 1:47:58 Mar 25, 2007 AND RETRIEVED FROM THE
     INTERNET ARCHIVE ON 1:02:31 Aug 15, 2011.
     JAVASCRIPT APPENDED BY WAYBACK MACHINE, COPYRIGHT INTERNET ARCHIVE.

     ALL OTHER CONTENT MAY ALSO BE PROTECTED BY COPYRIGHT (17 U.S.C.
     SECTION 108(a)(3)).
-->








<script type="text/javascript">
  var wmNotice = "Wayback - External links, forms, and search boxes may not function within this collection. Url: http://www.usstudents.org:80/p.asp?WebPage_ID=107 time: 1:47:58 Mar 25, 2007";
  var wmHideNotice = "hide";
</script>
<script type="text/javascript" src="http://staticweb.archive.org/js/disclaim.js"></script>
</body>
</html>


