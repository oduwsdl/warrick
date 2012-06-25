function showsubmenu(nr)
{
	if (document.layers)
	{
		current = (document.layers[nr].display == 'none') ? 'block' : 'none';
		document.layers[nr].display = current;
	}
	else if (document.all)
	{
		current = (document.all[nr].style.display == 'none') ? 'block' : 'none';
		document.all[nr].style.display = current;
	}
	else if (document.getElementById)
	{
		vista = (document.getElementById(nr).style.display == 'none') ? 'block' : 'none';
		document.getElementById(nr).style.display = vista;
	}
}

function goemail(user)
{
        /* anti-spamcrawl */
        var url = 'mailto:';
        url += user + '@cs.odu.edu';
        location.href = url;
}

function writetolayer(layername,text)
{
	if( document.layers) {
                var oLayer;
                oLayer = document.layers[layername].document;
                oLayer.open();
                oLayer.write(text);
                oLayer.close();
        } else if( parseInt(navigator.appVersion)>=5&&navigator.appName=="Netscape") {
                document.getElementById(layername).innerHTML = text;
        } else if (document.all) document.all[layername].innerHTML = text;
}

function showphone(phone1, phone2, fax1, fax2, username)
{
	var layername = username+"_phone";
	var text='Office: '+phone1+'-'+phone2;
	if( fax1 )
		text = text +'<BR>Fax: '+fax1+'-'+fax2+'<br>';
	writetolayer(layername,text);
}

function showemail(email1, email2, username)
{
	var layername = username+"_email";
	var text='<a href="mailto:'+email1+'@'+email2+'">'+email1+'@'+email2+'</a> ';
		text = 'Email: '+text;
	writetolayer(layername,text);
}
