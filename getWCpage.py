print "Content-Type: text/html\n\n"
#print "Content-Type: text/plain\n\n"

#mfc [ Memento Frequency Change] 
from urllib2 import urlopen, Request,URLError,HTTPError
import cgi # to read parameters
import time
import csv

def archiveIt(url):
	user_agent = 'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.1.10) Gecko/20100504 Firefox/3.5.10 (.NET CLR 3.5.30729)'
	cki='__utma=9542323.159307680.1287558370.1290491687.1291005002.12; __utmz=9542323.1289806958.5.2.utmccn=(organic)|utmcsr=google|utmctr=webcitation|utmcmd=organic; rsi_segs_ttn=A09801_10163|A09801_10187|A09801_10014|A09801_10079|A09801_10017|A09801_10158|A09801_10157|A09801_10002|A09801_10205|A09801_10001|A09801_10091|A09801_10092|A09801_10098|A09801_10099|A09801_10100|A09801_10182|A09801_10203|A09801_10217; PHPSESSID=2694b89422efbfd2e4485b9471f4378a; s_sess=%20s_cc%3Dtrue%3B%20s_sq%3D%3B; __utmc=9542323'
	headers = {'User-Agent': user_agent, 'Connection':'keep-alive', 'Keep-Alive':'115'}
	baseurl = url
	req=Request(baseurl,None,headers)
	response = urlopen(req)
	data=response.read()
	print data

	
def getArcType(url):
	if url.find("http://www.diigo.com")>=0:
		arType="Diigo"
	elif url.find(".archive-it.org")>=0:
		arType = "archive-it"
	elif url.find("http://cc.bingj.com")>=0:
		arType = "Bing"
	elif url.find("http://uk.wrs.yahoo.com")>=0:
		arType="Yahoo"
	elif url.find("webcitation.org")>=0:
		arType="Webcitation"
	elif url.find("http://web.archive.org")>=0:
		arType="ArcORG"
	elif url.find("http://webarchive.nationalarchives.gov.uk")>=0:
		arType="NationalA"
	else:
		arType="Else"
	return (arType)	
	
def getWCPage(url):
	user_agent = 'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.1.10) Gecko/20100504 Firefox/3.5.10 (.NET CLR 3.5.30729)'
	cki='__utma=9542323.159307680.1287558370.1290491687.1291005002.12; __utmz=9542323.1289806958.5.2.utmccn=(organic)|utmcsr=google|utmctr=webcitation|utmcmd=organic; rsi_segs_ttn=A09801_10163|A09801_10187|A09801_10014|A09801_10079|A09801_10017|A09801_10158|A09801_10157|A09801_10002|A09801_10205|A09801_10001|A09801_10091|A09801_10092|A09801_10098|A09801_10099|A09801_10100|A09801_10182|A09801_10203|A09801_10217; PHPSESSID=2694b89422efbfd2e4485b9471f4378a; s_sess=%20s_cc%3Dtrue%3B%20s_sq%3D%3B; __utmc=9542323'
	headers = {'User-Agent': user_agent, 'Connection':'keep-alive', 'Keep-Alive':'115','Cookie':cki}
	baseurl = url
	req=Request(baseurl,None,headers)
	response = urlopen(req)
	data=response.read()

	#print "<br>------------------MAINFRAME.PHP-------------------------------------<br>"
	baseurl="http://www.webcitation.org/mainframe.php"
	req=Request(baseurl,None,headers)
	response = urlopen(req)
	data=response.read()
	#print data
	WCurl = data
	print WCurl
	return (WCurl)
	#print "<br>-------------------END------------------------------------<br>"	
	
if __name__	== '__main__':
	parm=cgi.FieldStorage()
	url = parm.getvalue('url')
	arType = getArcType(url)
	if arType=="Webcitation":
		getWCPage(url)
	elif arType=="bing":
		print "bing"
	elif arType=="Yahoo":
		print "yahoo"
	elif arType=="archive-it":
		 archiveIt(url)
	else:
		print "Else"
	#print "End."

