# Libraries ----
library(dplyr)
library(stringr)
library(rvest)
library(purrr)
library(fs)
library(tidyr)
library(xlsx)

# Webpages ----
webpages <- fs::dir_ls("static-files\\webpages", regexp = "\\.html$")

## Webpage Table ----
webpage_table <-webpages%>%
  map(.f=~read_html(.x)%>%
        html_elements("tbody")%>%
        html_table()%>%
        pluck(1)%>%
        janitor::remove_empty(which = c("cols"))%>%
        rename_with(.cols = everything(), ~c("Entity.Name","ID.Number","Old.ID.Number","Address","ID"))%>%
        mutate(ID = 1:n(),
               Series.Source = tools::file_path_sans_ext(basename(.x)),
               Date.Scraped = str_sub(Series.Source,-10,-1),
               Series.Source = str_sub(Series.Source,1,-12)))%>%
  bind_rows()

## Webpage Sites ----
webpage_sites <-webpages%>%
  map(.f=~read_html(.x)%>%
        html_elements('td')%>%   
        html_elements("a.link")%>%
        html_attr("href")%>%
        tibble::as_tibble()%>%
        slice_head(prop = .5)%>%
        mutate(ID = 1:n(),
               Series.Source = tools::file_path_sans_ext(basename(.x)),
               Series.Source = str_sub(Series.Source,1,-12))%>%
        rename(Sub.Website = value))%>%
  bind_rows()

## Scraped Data ----
scraped_data <- webpage_table%>%
  left_join(webpage_sites, by = c("ID","Series.Source"))


# Sub-Webpages ----

sub_data <- scraped_data%>%
  select(Sub.Website)%>%   #ID,Series.Source,Date.Scraped,
  distinct()%>%
  unlist()


scraped_sub_data<-sub_data%>%
  map(.f = ~.x%>%
        session()%>%
        html_elements("td")%>%
        html_elements("table")%>%
        html_elements("tr")%>%
        html_text2()%>%
        tibble::as_tibble()%>%
        mutate(Sub.Website = .x)%>%
        filter(!str_detect(value,"Identification Number:"),
               !str_detect(value,"ID Number:"),
               !str_detect(value,"\\*"))%>%
        mutate(Address.Subfield = case_when(str_detect(value,"The name and address of the Resident Agent:")~value,
                                            str_detect(value,"Registered Office Mailing address:")~value,
                                            str_detect(value,"The Officers and Directors of the Corporation:")~value,
                                            str_detect(value,"Title	Name	Address")~value,
                                            str_detect(value,"Total Authorized Shares:")~"Shares",
                                            TRUE~as.character(NA)))%>%
        fill(Address.Subfield, .direction = c("down"))%>%
        mutate(Address.Subfield = case_when(is.na(Address.Subfield)~"",
                                            value == Address.Subfield ~ "DEL",
                                            TRUE~Address.Subfield),
               value = case_when(str_detect(value,"City:")~gsub(":","",value),
                                 TRUE~value),
               temp1 = gsub(":(.*)","",value),
               temp2 = gsub("^[^:]+:\\s*","",value),
               temp1 = case_when(value==temp1~gsub("\\s(.*)","",value),
                                 TRUE~temp1),
               temp1 = case_when(str_detect(Address.Subfield,"Title	")~Address.Subfield,
                                 str_detect(temp1,"The name of the ")~gsub("The name of the ","",temp1),
                                 str_detect(temp1,"Resident ")~gsub("Resident ","",temp1),
                                 temp1=="City"~"City, State, Zip Code",
                                 TRUE~temp1),
               # temp2 = case_when(value==temp2~gsub("^\\S*","",value),
               #                   TRUE~temp2),
               temp2 = case_when(str_detect(temp2,"City")~gsub("City","",temp2),
                                 TRUE~temp2),
               temp2 = case_when(str_detect(temp2,"State")~gsub("State",",",temp2),
                                 TRUE~temp2),
               temp2 = case_when(str_detect(temp2,"Zip Code")~gsub("Zip Code",",",temp2),
                                 TRUE~temp2))%>%
        filter(!str_detect(Address.Subfield,"DEL"))%>%
        mutate_if(is.character, str_trim)%>%
        mutate(Address.Subfield = case_when(Address.Subfield == "The name and address of the Resident Agent:"~Address.Subfield,
                                            Address.Subfield == "Registered Office Mailing address:"~Address.Subfield,
                                            TRUE~""))%>%
        select(-value)%>%
        rename(Field = temp1,
               Value = temp2))%>%
  bind_rows()


#saveRDS(scraped_sub_data,"scraped_sub_data.RDS")

# Data ---- 
scraped_data<-scraped_data%>%
  left_join(scraped_sub_data,by = c("Sub.Website"))%>%
  select(ID,
         Series.Source,
         Entity.Name,
         ID.Number,
         Old.ID.Number,
         Address,
         Address.Subfield,
         Field,
         Value,
         Date.Scraped,
         Sub.Website)

# Wrangle Data ----

## Main Data
temp <- scraped_data%>%
  select(-Date.Scraped,-Sub.Website)

# Removing Duplicates
temp0 <- temp%>%
  select(-ID)

# Create List of Dups
check <- temp0%>%select(Series.Source,Entity.Name)%>%
  distinct()%>%
  group_by(Entity.Name)%>%
  mutate(check = 1:n())%>%
  filter(check > 1)%>%
  mutate(DEL = paste0(Series.Source,Entity.Name))%>%ungroup()%>%
  select(DEL)%>%
  unlist()

# filter out Dups from main data  
temp <- temp%>%
  mutate(DEL = paste0(Series.Source,Entity.Name))%>%
  filter(!DEL %in% check)

# first data set
temp1 <- temp%>%
  select(ID,Entity.Name,ID.Number,Old.ID.Number,Address)%>%
  distinct()%>%
  mutate(ID = 1:n())

# second data set
temp2<-temp0%>%
  left_join(temp1, by = c("Entity.Name","ID.Number","Old.ID.Number","Address"))%>%
  select(ID,
         Series.Source,
         Entity.Name,
         ID.Number,
         Old.ID.Number,
         Address,
         Address.Subfield,
         Field,
         Value
  )%>%
  mutate(Value = case_when(str_detect(Value,",\t\r\r\t\r,")~"",
                           TRUE~Value),
         Address.Subfield = case_when(Address.Subfield=="The name and address of the Resident Agent:"~ "Resident Agent Address",
                                      Address.Subfield=="Registered Office Mailing address:"~" Office Mailing Address",
                                      TRUE~Address.Subfield),
         Field = case_when(Field=="DOMESTIC PROFIT CORPORATION"~"Domestic Profit Corporation",
                           Field=="DOMESTIC LIMITED LIABILITY COMPANY"~"Domestic Limited Liability Company",
                           Field=="FOREIGN PROFIT CORPORATION"~"Foreign Profit Corporation",
                           Field=="DOMESTIC NONPROFIT CORPORATION"~"Domestic Non-Profit Corporation",
                           Field=="DOMESTIC LIMITED PARTNERSHIP"~"Domestic Limited Partnership",
                           Field=="FOREIGN LIMITED LIABILITY COMPANY"~"Foreign Limited Liability Company",
                           Field=="DOMESTIC LIMITED LIABILITY PARTNERSHIP"~"Domestic Limited Liability",
                           Field=="DOMESTIC PROFESSIONAL CORPORATION"~"Domestic Professional Corporation",
                           Field=="FOREIGN NONPROFIT CORPORATION"~"Foreign Non-Profit Corporation",
                           Field=="FOREIGN LIMITED PARTNERSHIP"~"Foreign Limited Partnership",
                           Field=="DOMESTIC PROFESSIONAL LIMITED LIABILITY COMPANY"~"Domestic Professional Limited Liability Company",
                           TRUE ~ Field))


view<-temp2%>%
  distinct(Field)
rm(view)

# Excel Tabs ----
temp2 <- as.data.frame(temp2)

first_tab <- temp2%>%
  select(ID,
         Entity.Name,
         #ID.Number,
         #Old.ID.Number,
         Address
  )%>%
  distinct()

second_tab <- temp2%>%
  select(ID,
         Field,
         Address.Subfield,
         Value
  )%>%
  rename(Sub.Field = Address.Subfield)%>%
  distinct()

data_tab <- temp2

# Write to Excel ----
Entities <- openxlsx::loadWorkbook(here::here("static-files","Entities.xlsx"))
openxlsx::writeData(Entities, sheet = "Pull-Primary", first_tab)
openxlsx::writeData(Entities, sheet = "Pull-Secondary", second_tab)
openxlsx::writeData(Entities, sheet = "Data", data_tab)
openxlsx::saveWorkbook(Entities, here::here("Entities", paste0("Entities-",Sys.Date(),".xlsx")), overwrite = T)
