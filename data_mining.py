# Modules
import unittest, time, re, math, os
from datetime import datetime
from datetime import timedelta
import pandas as pd
import dateutil.parser as dparser
from pathlib import Path

# Selenium
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import Select
from selenium.webdriver.common.action_chains import ActionChains
from selenium.common.exceptions import NoSuchElementException
from selenium.common.exceptions import NoAlertPresentException

# Path
pathName = "D:\\src\\Data-Mining-DoC\\static-files"

# Create Directory
new_dir = "webpages"
isExist = os.path.exists(pathName + '\\' + new_dir)
if not isExist:
   os.makedirs(pathName+ '\\' +new_dir)

# Formats
fullPath = pathName + "\\" + new_dir + "\\"
today = datetime.today()
today = today.strftime("%Y-%m-%d")

# Start Selenium
chrome_path = pathName+"\\"+"chromedriver.exe"   
#to update chromedriver to match Chrome version 107 go to  https://chromedriver.storage.googleapis.com/index.html
driver = webdriver.Chrome(chrome_path)
driver.get("https://cofs.lara.state.mi.us/SearchApi/Search/Search")


with open(pathName+'\\terms.txt') as f:
    alphabet = f.read().splitlines()


def hasXpath(text):
    try:
        driver.find_element_by_link_text(text)
        return True
    except:
        return False

##### Start loop with term list
for letter in alphabet:        
    # intial pages search for entity name     
    search_box = driver.find_element("xpath",'//*[@id="txtEntityName"]') 
    search_box.click()                                                    
    search_box.clear()                                                                          
    search_box.send_keys(letter)
    time.sleep(.5)
    # added the following selection to change `Begins with` to ``keyword`
    search_type = driver.find_element("xpath",'//*[@id="ddlEntitySearchType"]/option[3]')
    search_type.click()
    time.sleep(.5)
    # added the following selection to change `25 per page` to ``100 per page`
    search_type = driver.find_element("xpath",'//*[@id="pagesizeSelection"]/option[3]')   
    search_type.click()
    time.sleep(.5)
 
    page_objects = driver.find_element("xpath",'//*[@id="pagesizeSelection"]/option[3]').text 
    page_objects = int(page_objects.replace(' Pages', ''))
    time.sleep(.5)
    search_box.send_keys(Keys.RETURN)
    time.sleep(2)
    # page information
    pages = driver.find_element("xpath",'//*[@id="TotalPages"]').text
    pages = int(pages.replace('Number of Pages: ', ''))    
    nextEllipsis = math.ceil(pages/25)+1 # 25 here is the number of options used with the gridPager / demarcations of webpage for term 
    time.sleep(1)
##### START PAGE LOOP    
    page = 1
    while page < 2: 
        try:
            time.sleep(.5)    
            #save page
            with open(fullPath+str(letter)+'-page-'+str(page)+'-'+today+'.html', 'w') as f:
                f.write(driver.page_source)
            time.sleep(.5)
            page = page + 1
            time.sleep(1)
        except:
            print("passed page "+ str(page))
            page = page + 1
            time.sleep(1)
    while  page < 24: 
        try:
            time.sleep(.5)    
            page_selection = driver.find_element("xpath",'/html/body/div[2]/div[3]/div/div[3]/div/div/div[2]/div/a['+str(page)+']')      
            page_selection.click()
            time.sleep(.5)
            with open(fullPath+str(letter)+'-page-'+str(page)+'-'+today+'.html', 'w') as f:
                f.write(driver.page_source)
            time.sleep(.5)
            page = page + 1
            time.sleep(1)
        except:
            print("passed page "+ str(page))
            page = page + 1
            time.sleep(1)
    # Due to weird site navigation the following is a work around
    if (page>23):
        if(page<=pages):
            ellipsis = 1   
               
            for ellipsis in range(1,nextEllipsis):
                pageStart = 4
                pageEnd = 26
                while pageStart < pageEnd:
                    try:
                        time.sleep(.5)
                        page_selection = driver.find_element("xpath",'/html/body/div[2]/div[3]/div/div[3]/div/div/div[2]/div/a['+str(pageStart)+']')  
                        page_selection.click()
                        time.sleep(1)
                        with open(fullPath+str(letter)+'-page-'+str(page)+'-'+today+'.html', 'w') as f:
                            f.write(driver.page_source)
                        time.sleep(.5)
                        page=page+1
                        pageStart = pageStart + 1
                        time.sleep(1)
                    except:
                        print("passed page "+str(page))
                        page = page + 1
                        pageStart = pageStart + 1
                        time.sleep(1)
                ellipsis = ellipsis + 1
                time.sleep(1)
                # after the given search move to next search
    driver.find_element("xpath",'//*[@id="newSearch"]').click()
    time.sleep(1)

