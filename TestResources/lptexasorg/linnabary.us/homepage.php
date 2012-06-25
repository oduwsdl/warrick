<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head><base href="http://www.linnabary.us/HomePage.php" />
<meta content="text/html; charset=UTF-8" http-equiv="content-type" /><title>Linnabary2008</title>

<link rel="stylesheet" href="./css/ui-reset.css" type="text/css" />
<link rel="stylesheet" href="./css/linnabary2008.css" type="text/css" />
<link rel="stylesheet" href="./css/horizontal-menu.css" type="text/css" />

<link rel="stylesheet" href="/phplayersmenu/layersmenu-demo.css" type="text/css"></link>
<link rel="stylesheet" href="/phplayersmenu/layersmenu-gtk2.css" type="text/css"></link>
<link rel="shortcut icon" href="/phplayersmenu/LOGOS/shortcut_icon_phplm.png"></link>

<script language="JavaScript" type="text/javascript">
<!--
// PHP Layers Menu 3.2.0-rc (C) 2001-2004 Marco Pratesi - http://www.marcopratesi.it/

DOM = (document.getElementById) ? 1 : 0;
NS4 = (document.layers) ? 1 : 0;
// We need to explicitly detect Konqueror
// because Konqueror 3 sets IE = 1 ... AAAAAAAAAARGHHH!!!
Konqueror = (navigator.userAgent.indexOf('Konqueror') > -1) ? 1 : 0;
// We need to detect Konqueror 2.2 as it does not handle the window.onresize event
Konqueror22 = (navigator.userAgent.indexOf('Konqueror 2.2') > -1 || navigator.userAgent.indexOf('Konqueror/2.2') > -1) ? 1 : 0;
Konqueror30 =
	(
		navigator.userAgent.indexOf('Konqueror 3.0') > -1
		|| navigator.userAgent.indexOf('Konqueror/3.0') > -1
		|| navigator.userAgent.indexOf('Konqueror 3;') > -1
		|| navigator.userAgent.indexOf('Konqueror/3;') > -1
		|| navigator.userAgent.indexOf('Konqueror 3)') > -1
		|| navigator.userAgent.indexOf('Konqueror/3)') > -1
	)
	? 1 : 0;
Konqueror31 = (navigator.userAgent.indexOf('Konqueror 3.1') > -1 || navigator.userAgent.indexOf('Konqueror/3.1') > -1) ? 1 : 0;
// We need to detect Konqueror 3.2 and 3.3 as they are affected by the see-through effect only for 2 form elements
Konqueror32 = (navigator.userAgent.indexOf('Konqueror 3.2') > -1 || navigator.userAgent.indexOf('Konqueror/3.2') > -1) ? 1 : 0;
Konqueror33 = (navigator.userAgent.indexOf('Konqueror 3.3') > -1 || navigator.userAgent.indexOf('Konqueror/3.3') > -1) ? 1 : 0;
Opera = (navigator.userAgent.indexOf('Opera') > -1) ? 1 : 0;
Opera5 = (navigator.userAgent.indexOf('Opera 5') > -1 || navigator.userAgent.indexOf('Opera/5') > -1) ? 1 : 0;
Opera6 = (navigator.userAgent.indexOf('Opera 6') > -1 || navigator.userAgent.indexOf('Opera/6') > -1) ? 1 : 0;
Opera56 = Opera5 || Opera6;
IE = (navigator.userAgent.indexOf('MSIE') > -1) ? 1 : 0;
IE = IE && !Opera;
IE5 = IE && DOM;
IE4 = (document.all) ? 1 : 0;
IE4 = IE4 && IE && !DOM;

// -->
</script>
<script language="JavaScript" type="text/javascript" src="/phplayersmenu/libjs/layersmenu-library.js"></script>
<script language="JavaScript" type="text/javascript" src="/phplayersmenu/libjs/layersmenu.js"></script>

<!-- beginning of menu header - PHP Layers Menu 3.2.0-rc (C) 2001-2004 Marco Pratesi - http://www.marcopratesi.it/ -->

<script language="JavaScript" type="text/javascript">
<!--

menuTopShift = 6;
menuRightShift = 7;
menuLeftShift = 2;

var thresholdY = 1;
var abscissaStep = 140;

toBeHidden = new Array();
toBeHiddenLeft = new Array();
toBeHiddenTop = new Array();

listl = ['L2','L5','L8'];
var numl = listl.length;

father = new Array();
for (i=1; i<=12; i++) {
	father['L' + i] = '';
}
father_keys = ['L3','L4','L6','L7','L9','L10','L11','L12'];
father_vals = ['L2','L2','L5','L5','L8','L8','L8','L8'];
for (i=0; i<father_keys.length; i++) {
	father[father_keys[i]] = father_vals[i];
}

lwidth = new Array();
var lwidthDetected = 0;

function moveLayers()
{
	if (!lwidthDetected) {
		for (i=0; i<numl; i++) {
			lwidth[listl[i]] = getOffsetWidth(listl[i]);
		}
		lwidthDetected = 1;
	}
	if (IE4) {
		for (i=0; i<numl; i++) {
			setWidth(listl[i], abscissaStep);
		}
	}
	var hormenu1TOP = getOffsetTop('hormenu1L1');
	var hormenu1HEIGHT = getOffsetHeight('hormenu1L1');
	setTop('L2', hormenu1TOP + hormenu1HEIGHT);
	moveLayerX1('L2', 'hormenu1');
	setTop('L5', hormenu1TOP + hormenu1HEIGHT);
	moveLayerX1('L5', 'hormenu1');
	setTop('L8', hormenu1TOP + hormenu1HEIGHT);
	moveLayerX1('L8', 'hormenu1');

}

back = new Array();
for (i=1; i<=12; i++) {
	back['L' + i] = 0;
}

// -->
</script>

<!-- end of menu header - PHP Layers Menu 3.2.0-rc (C) 2001-2004 Marco Pratesi - http://www.marcopratesi.it/ -->

<!-- IE Doesn't comply with the CSS opacity property. It requires a IE specific filter setting. filter: alpha(opacity=85); -->
<!-- IE doesn't render opacity on Div's without a width property -->
<!--[if IE]>
<style>
.PageHeaderBanner {
width: 100%;
filter: alpha(opacity=85);
}
.CenterPageColumn {
margin-top: 1.5em;
}
</style>
<![endif]-->
<script type="text/javascript" src="./js/prototype-1.6.0.2.js">
</script>


</head>
<body>
<div id="PageHeader" class="PageHeader" align="center">
<div id="PageHeaderBanner" class="PageHeaderBanner"><img id="BannerImage" style="width: 728px; height: 90px;" alt="Linnabary2008SiteBanner" src="images/Banner-728x90.gif" align="top" hspace="0" vspace="0" /></div>
<div id="PageHeaderHorizontalMenu" class="PageHeaderHorizontalMenu">
<div id="HorizontalMainMenu" align="center">
<!-- beginning of horizontal menu bar -->

<table border="0" cellspacing="0" cellpadding="0">
<tr>
<td>
<div class="horbar">
<table border="0" cellspacing="0" cellpadding="0">
<tr>
<td>
<div id="hormenu1L1" class="horbaritem" onmouseover="clearLMTO();" onmouseout="setLMTO();">
<a href="/" onmouseover="shutdown();" title="Steve Linnabary for Congress 2008"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />Home&nbsp;&nbsp;&nbsp;</a>
</div>
</td>
<td>
<div id="hormenu1L2" class="horbaritem" onmouseover="clearLMTO();" onmouseout="setLMTO();">
<a href="#" onmouseover="moveLayerX1('L2', 'hormenu1') ; LMPopUp('L2', false);"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />The Candidate&nbsp;<img
src="/phplayersmenu/menuimages/down-arrow.png" width="9" height="5"
border="0" alt=">>" />&nbsp;&nbsp;&nbsp;</a>
</div>
</td>
<td>
<div id="hormenu1L5" class="horbaritem" onmouseover="clearLMTO();" onmouseout="setLMTO();">
<a href="#" onmouseover="moveLayerX1('L5', 'hormenu1') ; LMPopUp('L5', false);"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />The Constituents&nbsp;<img
src="/phplayersmenu/menuimages/down-arrow.png" width="9" height="5"
border="0" alt=">>" />&nbsp;&nbsp;&nbsp;</a>
</div>
</td>
<td>
<div id="hormenu1L8" class="horbaritem" onmouseover="clearLMTO();" onmouseout="setLMTO();">
<a href="#" onmouseover="moveLayerX1('L8', 'hormenu1') ; LMPopUp('L8', false);"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />Libertarians&nbsp;<img
src="/phplayersmenu/menuimages/down-arrow.png" width="9" height="5"
border="0" alt=">>" />&nbsp;&nbsp;&nbsp;</a>
</div>
</td>
</tr>
</table>
</div>
</td>
</tr>
</table>

<!-- end of horizontal menu bar -->

</div>
</div>
</div>
<div id="PageBody" class="PageBody">
<div id="LeftPageColumn" class="LeftPageColumn">
<div id="MeetTheCandidateLink" class="LeftPageColumnArticle">
<h2 style="float: right;">Meet the Candidate - Why Steve
Linnabary Deserves your Vote!</h2>
<center>
<p><img style="border: 1px solid ; width: 160px; height: 120px;" alt="Steve Linnabary" src="images/Steve1/PIC_1203.JPG" hspace="2" vspace="2" /></p>
</center>
</div>
<div id="MeetAnotherLibertarianCandidate" class="LeftPageColumnArticle">
<h2>Meet Another Libertarian Running for Office</h2>
<p>
</p>
<img style="width: 160px; height: 120px;" src="images/image-placholder.gif" alt="Picture of Another Libertarian Running for Office" />
<h3>Libertarian
Candidates Run for Office for the
Right Reasons
</h3>
There's
no huge corporate lobbyist funding these
folks.
Meet other citizens who have decideed to toss their hat's into
the ring in order to enhance the communities that they live in. </div>
</div>
<!-- end LeftPageColumn -->
<div id="RightPageColumn" class="RightPageColumn">
<div id="NationalPresidentialCandidateLink" class="RightPageColumnArticle">
<h2>Bob Barr for President!</h2>
<center>
<p><a href="http://www.bobbarr2008.com/" target="_blank"><img style="border: 1px solid ; width: 160px; height: 133px;" alt="National Presidential Candidate Banner" src="http://www.bobbarr2008.com/uploads/image/6.jpg" /></a></p>
</center>
</div>
<div id="StatePartyLink" class="RightPageColumnArticle">
<h2>Endorsed by the Ohio Libertarian Party!</h2>
<center>
<p><a href="http://www.lpo.org/" target="_blank"><img style="border: 1px solid ; width: 200px; height: 80px;" src="images/LPO/LPOBanner.jpg" alt="State Party Banner" /></a></p>
</center>
</div>
<div id="GotoWashington" class="RightPageColumnArticle">
<h2>Mr. Linnabary Goes to Washington!</h2>
<p>
<img style="border: 1px solid ; width: 160px; height: 120px; float: left;" alt="Steve Linnabary" src="images/Steve1/PIC_1203.JPG" hspace="2" vspace="2" />Our Candidate BLOG's on the
issue's facing our state, nation, and most importantly our
constituents. We're still working on linking in Steve's Blog. Check
back next week!</p>
</div>
</div>
<!-- end RightPageColumn -->
<div id="CenterPageColumn" class="CenterPageColumn">
<div class="CenterPageColumnHeader">
		<h1>Steve Linnabary for Congress 2008</h1>
		<p style="text-align: center">Remember to Vote for Steve on Tuesday, November 4</p>
</div>
		<div class="CenterPageColumnArticle">
			<h2><a href="http://www.linnabary.us/wordpress/?p=9" target="_blank">Steve Linnabary announces his candidacy for Ohio’s 12th Congressional Seat</a></h2>
			<p>Steve Linnabary announced his intentions to run for Ohio&#8217;s 12th Congressional District.  The central Ohio district includes parts of Franklin and Delaware County in and around Columbus.  The congressional seat is currently held by Republican Pat Tiberi.  Steve will be campaiging on the Libertarian party ticket to bring fiscal responsibility to goverment.</p>
			<p><small>Posted on 20 October 2008 | 10:43 am</small></p>
		</div>
		<div class="CenterPageColumnArticle">
			<h2><a href="http://www.linnabary.us/wordpress/?p=3" target="_blank">Ohio Libertarian Party Gains Equal Access to the Ballot</a></h2>
			<p>The Libertarian Party of Ohio has successfully fought and achieved ballot access in Ohio.  Libertarian Party candidate names will be associated with the party on Ohio ballots this November.  Look for the &#8220;Libertarian Party&#8221; by our candidates name.</p>
			<p><small>Posted on 20 October 2008 | 10:29 am</small></p>
		</div>
<div class="CenterPageColumnArticle"></div>
</div>
<!-- Clearing both at the end of the PageBody brings the background-color all the way through the div and fills out the left and right columns -->
<div style="clear: both;"></div>
<!-- end CenterPageColumn -->
</div>
<!-- end PageBody -->
<!-- beginning of menu footer - PHP Layers Menu 3.2.0-rc (C) 2001-2004 Marco Pratesi - http://www.marcopratesi.it/ -->


<div id="L2" class="submenu" onmouseover="clearLMTO();" onmouseout="setLMTO();">
<table border="0" cellspacing="0" cellpadding="0">
<tr>
<td nowrap="nowrap">
<div class="subframe">
<div id="refL3" class="item">
<a href="#" onmouseover="LMPopUp('L2', true);" title="Steve Linnabary's Biography"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />Steve's Biography&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a>
</div>
<div id="refL4" class="item">
<a href="#" onmouseover="LMPopUp('L2', true);" title="Steve Linnabary's Family"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />Steve's Family&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a>
</div>
</div>
</td>
</tr>
</table>
</div>

<div id="L5" class="submenu" onmouseover="clearLMTO();" onmouseout="setLMTO();">
<table border="0" cellspacing="0" cellpadding="0">
<tr>
<td nowrap="nowrap">
<div class="subframe">
<div id="refL6" class="item">
<a href="http://en.wikipedia.org/wiki/Ohio's_12th_congressional_district" onmouseover="LMPopUp('L5', true);" title="12th Congressional District" target="_blank"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />12th Congressional District&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a>
</div>
<div id="refL7" class="item">
<a href="#" onmouseover="LMPopUp('L5', true);"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />Incumbent and Opposition Candidates&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a>
</div>
</div>
</td>
</tr>
</table>
</div>

<div id="L8" class="submenu" onmouseover="clearLMTO();" onmouseout="setLMTO();">
<table border="0" cellspacing="0" cellpadding="0">
<tr>
<td nowrap="nowrap">
<div class="subframe">
<div id="refL9" class="item">
<a href="http://www.lp.org/" onmouseover="LMPopUp('L8', true);" title="The Libertarian Party" target="_blank"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />The Libertarian Party&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a>
</div>
<div id="refL10" class="item">
<a href="http://www.lpo.org/" onmouseover="LMPopUp('L8', true);" title="The Ohio Libertarian Party" target="_blank"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />The Ohio Libertarian Party&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a>
</div>
<div id="refL11" class="item">
<a href="http://www.lpo.org/counties/Delaware.php" onmouseover="LMPopUp('L8', true);" title="Delaware County Libertarian Party" target="_blank"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />Delaware County Libertarian Party&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a>
</div>
<div id="refL12" class="item">
<a href="http://www.lpo.org/counties/Franklin.php" onmouseover="LMPopUp('L8', true);" title="Franklin County Libertarian Party" target="_blank"><img
align="top" src="/phplayersmenu/menuimages/transparent.png" width="1" height="16" border="0"
alt="" />Franklin County Libertarian Party&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</a>
</div>
</div>
</td>
</tr>
</table>
</div>


<script language="JavaScript" type="text/javascript">
<!--
loaded = 1;
// -->
</script>

<!-- end of menu footer - PHP Layers Menu 3.2.0-rc (C) 2001-2004 Marco Pratesi - http://www.marcopratesi.it/ -->





<!--
     FILE ARCHIVED ON 19:59:11 Nov 26, 2008 AND RETRIEVED FROM THE
     INTERNET ARCHIVE ON 1:01:32 Aug 15, 2011.
     JAVASCRIPT APPENDED BY WAYBACK MACHINE, COPYRIGHT INTERNET ARCHIVE.

     ALL OTHER CONTENT MAY ALSO BE PROTECTED BY COPYRIGHT (17 U.S.C.
     SECTION 108(a)(3)).
-->








<script type="text/javascript">
  var wmNotice = "Wayback - External links, forms, and search boxes may not function within this collection. Url: http://www.linnabary.us/HomePage.php time: 19:59:11 Nov 26, 2008";
  var wmHideNotice = "hide";
</script>
<script type="text/javascript" src="http://staticweb.archive.org/js/disclaim.js"></script>
</body></html>