# this.dir <- dirname(parent.frame(2)$ofile)
# setwd(this.dir)
# getwd()
# this.dir <- dirname(parent.frame(2)$ofile)
# script.dir <- dirname(sys.frame(1)$ofile)
# print(script.dir)

test <- require(elastic)
if(test == FALSE) install.packages("elastic")
require(elastic)

test <- require(ggplot2)
if(test == FALSE) install.packages("ggplot2")
require(ggplot2)

test <- require(scales)
if(test == FALSE) install.packages("scales")
require(scales)

test <- require(RColorBrewer)
if(test == FALSE) install.packages("RColorBrewer")
require(RColorBrewer)
rm(test)

test <- require(reshape)
if(test == FALSE) install.packages("reshape")
require(reshape)

test <- require(plyr)
if(test == FALSE) install.packages("plyr")
require(plyr)

# test <- require(rmarkdown)
# if(test == FALSE) install.packages("rmarkdown")
# require(rmarkdown)

# test <- require()
# if(test == FALSE) install.packages("")
# require()
rm(test)

connect(es_base = "https://search-rc-elasticsearch-cluster-zhtfwjechy4noqdtqablbofcxi.us-east-1.es.amazonaws.com", es_port = "")
# BASE QUERY SETTINGS
type <- 'master'
index <-'rc_nrgi1'

# QUERY BUILDER
query_list <- list()
basic_search_term_vector <- c('environment', 'consent', 'resettlement', 'consultation', 'arbitration', 'renegotiation', 'confidentiality')
multi_search_term_vector <- c('rent tax', 'profits tax', 'local content')
multi_search_cutoff <- 0.2
resource_term_vector <- c('hydrocarbons','oil','gas')

# base query
query_list[['yearly_total']] <- '{
  "aggregations": {
    "year_agg": {
      "terms": {
        "field": "signature_year",
        "size": 0
      }
    }
  }
}'

query_list[['missing']] <- '{
  "aggs" : {
    "without_text" : {
      "missing" : { "field" : "pdf_text_string" }
    }
  }
}'

# resource type query
for(term in resource_term_vector) {
  query_list[[term]] <- paste0('{
  "query": {
    "filtered": {
      "filter": {
        "term": {"resource": "',term,'"}
      }
    } 
  },
  "aggregations": {
    "year_agg": {
      "terms": {
        "field": "signature_year",
        "size": 0
      }
    }
  }
}')
}
query_list[['other_resource']] <- '{
  "query": {
    "filtered": {
      "filter": {
        "bool": {
          "must_not": [
            {"term": {"resource": "hydrocarbons"}},
            {"term": {"resource": "oil"}},
            {"term": {"resource": "gas"}}
          ]
        }
      }
    } 
  },
  "aggregations": {
    "year_agg": {
      "terms": {
        "field": "signature_year",
        "size": 0
      }
    }
  }
}'

# single search term querys
for(term in basic_search_term_vector) {
  query_list[[term]] <- paste0('{
  "query": {
    "filtered": {
      "filter": {
        "term": {"pdf_text_string": "',term,'"}
      }
    } 
  },
  "aggregations": {
    "year_agg": {
      "terms": {
        "field": "signature_year",
        "size": 0
      }
    }
  }
}')
}

for(term in multi_search_term_vector) {
  term_title <- gsub(" ", "_", term)
  query_list[[term_title]] <- paste0('{
    "min_score": ',multi_search_cutoff,',
    "query": {
      "filtered": {
        "filter": {
          "term": {"pdf_text_string": "',term,'"}
        }
      }
    },
    "aggregations": {
      "year_agg": {
        "terms": {
          "field": "signature_year",
          "size": 0
        }
      }
    }
  }')
}

body <- '{
    "min_score": 0.2,
    "query": {
      "filtered": {
        "filter": {
          "term": {"pdf_text_string": "response_local_content"}
        }
      }
    },
    "aggregations": {
      "year_agg": {
        "terms": {
          "field": "signature_year",
          "size": 0
        }
      }
    }
  }'

rm(term, term_title)
# body <- '{
#     "min_score": 0.2,
#     "query": {
#         "match": {
#             "pdf_text_string": "rent tax"
#         }
#     }
# }'

# country + term by year

#How many contracts are digitised?
# aggs <- 
# '{
#   "aggs" : {
#     "without_text" : {
#       "missing" : { "field" : "pdf_text_string" }
#     }
#   }
# }'
# ​
# missing <- Search( index = "rc_nrgi1", type = "master", body = aggs )$aggregations

# #Iraq + Environment
# years <- c(1950:2015)
# aggs <- '{
#           "query": {
#             "filtered": {
#               "filter": {
#                 "term": {"resource": "hydrocarbons"}
#               }
#             }
#           }
#         }'
# #How many contracts are digitised?
# aggs <- 
# '{
#   "aggs" : {
#     "without_text" : {
#       "missing" : { "field" : "pdf_text_string" }
#     }
#   }
# }'
# ​

#etc.



# API CALL
print('Sending query...')
response_list <- list()
for (i in names(query_list)) {
  response_list[[paste('response_', i, sep='')]] <- Search(index=index, type=type, body=query_list[[i]])
}
rm(i, multi_search_term_vector, multi_search_cutoff, basic_search_term_vector, resource_term_vector, type, index, query_list)

# ETL
# Totals df
totals_df <- data.frame('totals',response_list[["response_yearly_total"]]$hits$total)
colnames(totals_df) <- c('var','val')
totals_df <- rbind(totals_df, data.frame(var='total years', val=length(response_list[["response_yearly_total"]]$aggregations$year_agg$buckets)))
totals_df <- rbind(totals_df, data.frame(var='total missing', val=response_list$response_missing$aggregations$without_text$doc_count))
totals_df <- rbind(totals_df, data.frame(var='total hydrocarbons', val=response_list[["response_hydrocarbons"]]$hits$total))
totals_df <- rbind(totals_df, data.frame(var='total oil', val=response_list[["response_oil"]]$hits$total))
totals_df <- rbind(totals_df, data.frame(var='total gas', val=response_list[["response_gas"]]$hits$total))
totals_df <- rbind(totals_df, data.frame(var='other resources', val=response_list[["response_other_resource"]]$hits$total))

# Yearly stats
total_years <- length(response_list[["response_yearly_total"]]$aggregations$year_agg$buckets)
years <- vector()
total <- vector()
for (i in 1:total_years) {
  years <- c(years,response_list[["response_yearly_total"]]$aggregations$year_agg$buckets[[i]]$key)
  total <- c(total,response_list[["response_yearly_total"]]$aggregations$year_agg$buckets[[i]]$doc_count)
  # print(response$aggregations$year_agg$buckets[[i]])
}
yearly_df <- data.frame(years, total)
yearly_df <- yearly_df[order(years),]
rm(i, total, years, total_years)
response_vector <- names(response_list)[names(response_list) != "response_yearly_total"]

for(res in response_vector) {
  res_tot_years <-  length(response_list[[res]]$aggregations$year_agg$buckets)
  res_years <- vector()
  res_total <- vector()
  if (res_tot_years != 0) {
    for(i in 1:res_tot_years) {
      res_years <- c(res_years, response_list[[res]]$aggregations$year_agg$buckets[[i]]$key)
      res_total <- c(res_total,response_list[[res]]$aggregations$year_agg$buckets[[i]]$doc_count)
    }
    res_df <- data.frame(res_years, res_total)
    colnames(res_df) <- c('years', res)
    yearly_df <- merge(yearly_df, res_df, by="years", all=TRUE)
    yearly_df[paste0(res,'_perc')] <- yearly_df[res] / yearly_df["total"]
    rm(i, res_tot_years, res_years, res_total, res_df)
  } 
}
rm(res)

yearly_df$years <- as.Date(paste0(yearly_df$years, '-1-1'), '%Y-%m-%d')

# PLOTS
theme_hist <- theme_bw() +
  theme(plot.title = element_text(size = rel(2)),legend.position="none",axis.text.x = element_text(angle = 45, hjust = 1))

print('Yearly plot...')
hist_yearly <- ggplot(yearly_df, aes(years,total))
hist_yearly <- hist_yearly +
  geom_bar(stat="sum") +
  labs(title = "Total contracts by year",x='Signature year',y='Total contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist
ggsave(hist_yearly,file='./plots/hist_yearly.pdf',height=8.5,width=11)

print('Printing environment plot...')
hist_response_environment <- ggplot(yearly_df, aes(years,response_environment_perc))
hist_response_environment <- hist_response_environment +
  geom_bar(stat="sum") +
  labs(title = "Contracts mentioning 'environment' by year",x='Signature year',y='Percent of all contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist + scale_y_continuous(labels = percent)
ggsave(hist_response_environment,file='./plots/hist_response_environment.pdf',height=8.5,width=11)

print('Printing consent plot...')
hist_response_consent <- ggplot(yearly_df, aes(years,response_consent_perc))
hist_response_consent <- hist_response_consent +
  geom_bar(stat="sum") +
  labs(title = "Contracts mentioning 'consent' by year",x='Signature year',y='Percent of all contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist + scale_y_continuous(labels = percent)
ggsave(hist_response_consent,file='./plots/hist_response_consent.pdf',height=8.5,width=11)

print('Printing resettlement plot...')
hist_response_resettlement <- ggplot(yearly_df, aes(years,response_resettlement_perc))
hist_response_resettlement <- hist_response_resettlement +
  geom_bar(stat="sum") +
  labs(title = "Contracts mentioning 'resettlement' by year",x='Signature year',y='Percent of all contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist + scale_y_continuous(labels = percent)
ggsave(hist_response_resettlement,file='./plots/hist_response_resettlement.pdf',height=8.5,width=11)

print('Printing consultation plot...')
hist_response_consultation <- ggplot(yearly_df, aes(years,response_consultation_perc))
hist_response_consultation <- hist_response_consultation +
  geom_bar(stat="sum") +
  labs(title = "Contracts mentioning 'consultation' by year",x='Signature year',y='Percent of all contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist + scale_y_continuous(labels = percent)
ggsave(hist_response_consultation,file='./plots/hist_response_consultation.pdf',height=8.5,width=11)

print('Printing arbitration plot...')
hist_response_arbitration <- ggplot(yearly_df, aes(years,response_arbitration_perc))
hist_response_arbitration <- hist_response_arbitration +
  geom_bar(stat="sum") +
  labs(title = "Contracts mentioning 'arbitration' by year",x='Signature year',y='Percent of all contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist + scale_y_continuous(labels = percent)
ggsave(hist_response_arbitration,file='./plots/hist_response_arbitration.pdf',height=8.5,width=11)

print('Printing renegotiation plot...')
hist_response_renegotiation <- ggplot(yearly_df, aes(years,response_renegotiation_perc))
hist_response_renegotiation <- hist_response_renegotiation +
  geom_bar(stat="sum") +
  labs(title = "Contracts mentioning 'renegotiation' by year",x='Signature year',y='Percent of all contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist + scale_y_continuous(labels = percent)
ggsave(hist_response_renegotiation,file='./plots/hist_response_renegotiation.pdf',height=8.5,width=11)

print('Printing confidentiality plot...')
hist_response_confidentiality <- ggplot(yearly_df, aes(years,response_confidentiality_perc))
hist_response_confidentiality <- hist_response_confidentiality +
  geom_bar(stat="sum") +
  labs(title = "Contracts mentioning 'renegotiation' by year",x='Signature year',y='Percent of all contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist + scale_y_continuous(labels = percent)
ggsave(hist_response_confidentiality,file='./plots/hist_response_confidentiality.pdf',height=8.5,width=11)

print('Printing resource type plots...')
#create aggregation of total yearly contracts
resource_tmp_perc <- yearly_df[,c('years' ,'response_hydrocarbons_perc','response_oil_perc','response_gas_perc', 'response_other_resource_perc')]
colnames(resource_tmp_perc) <- c('Year', 'Hydrocarbons percentage', 'Oil percentage', 'Gas percentage', 'Other resource percentage')
resource_tmp_perc <- melt(resource_tmp_perc, id.vars='Year')
resource_tmp_perc$variable <- as.character(resource_tmp_perc$variable)
resource_tmp_perc$variable <- as.factor(resource_tmp_perc$variable)
resource_tmp_perc$variable <- factor(resource_tmp_perc$variable,levels=c('Hydrocarbons percentage','Oil percentage','Gas percentage', 'Other resource percentage'),ordered=TRUE)

# Plot yeary perc
line_resources_perc <- ggplot(resource_tmp_perc, aes(Year,value))
line_resources_perc <- line_resources_perc + 
  geom_line(aes(color=variable, fill=variable, order=desc(variable)), size=1.5) +
  theme_bw() +
  theme(plot.title = element_text(size = rel(2)),legend.position="bottom",axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = 'Contracts by resource type ',x='Year',y='Percentage total contracts',fill='Type',color='Type') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year")) +
  scale_y_continuous(labels = percent)
colors <- brewer.pal(name="Set2", n=nlevels(resource_tmp_perc$variable))
names(colors) <- rev(levels(resource_tmp_perc$variable))
line_resources_perc <- line_resources_perc + scale_fill_manual(values=colors) + scale_color_manual(values=colors)
ggsave(line_resources_perc,file='./plots/line_resources_perc.pdf',height=8.5,width=11)
rm(resource_tmp_perc)

#create aggregation of total yearly contracts
resource_tmp_tot <- yearly_df[,c('years' ,'response_hydrocarbons','response_oil','response_gas', 'response_other_resource')]
colnames(resource_tmp_tot) <- c('Year', 'Hydrocarbons', 'Oil', 'Gas', 'Other resource')
resource_tmp_tot <- melt(resource_tmp_tot, id.vars='Year')
resource_tmp_tot$variable <- as.character(resource_tmp_tot$variable)
resource_tmp_tot$variable <- as.factor(resource_tmp_tot$variable)
resource_tmp_tot$variable <- factor(resource_tmp_tot$variable,levels=c('Hydrocarbons','Oil','Gas', 'Other resource'),ordered=TRUE)

# Plot yearly totals
line_resources_tot <- ggplot(resource_tmp_tot, aes(Year,value))
line_resources_tot <- line_resources_tot + 
  geom_line(aes(color=variable, fill=variable, order=desc(variable)), size=1.5) +
  theme_bw() +
  theme(plot.title = element_text(size = rel(2)),legend.position="bottom",axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = 'Contracts by resource type ',x='Year',y='Total contracts',fill='Type',color='Type') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"))
colors <- brewer.pal(name="Set2", n=nlevels(resource_tmp_tot$variable))
names(colors) <- rev(levels(line_resources_tot$variable))
line_resources_tot <- line_resources_tot + scale_fill_manual(values=colors) + scale_color_manual(values=colors)
ggsave(line_resources_tot,file='./plots/line_resources_tot.pdf',height=8.5,width=11)
rm(line_resources_tot)



