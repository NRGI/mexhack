this.dir <- dirname(parent.frame(2)$ofile)
setwd(this.dir)

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

# test <- require()
# if(test == FALSE) install.packages("")
# require

connect(es_base = "https://search-rc-elasticsearch-cluster-zhtfwjechy4noqdtqablbofcxi.us-east-1.es.amazonaws.com", es_port = "")
# BASE QUERY SETTINGS
type <- 'master'
index <-'rc_nrgi1'

# QUERY BUILDER
query_list <- list()
basic_search_term_vector <- c('environment', 'consent', 'resettlement', 'consultation', 'arbitration', 'renegotiation', 'confidentiality')
names(query_list)
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
rm(term)


# API CALL
response_list <- list()
for (i in names(query_list)) {
  response_list[[paste('response_', i, sep='')]] <- Search(index=index, type=type, body=query_list[[i]])
}
rm(basic_search_term_vector, type, index, query_list)

# ETL
total_contracts <- response_list[["response_yearly_total"]]$hits$total
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
rm(i, total, years)
response_vector <- names(response_list)[names(response_list) != "response_yearly_total"]

for(res in response_vector) {
  res_tot_years <-  length(response_list[[res]]$aggregations$year_agg$buckets)
  res_years <- vector()
  res_total <- vector()
  for(i in 1:res_tot_years) {
    res_years <- c(res_years, response_list[[res]]$aggregations$year_agg$buckets[[i]]$key)
    res_total <- c(res_total,response_list[[res]]$aggregations$year_agg$buckets[[i]]$doc_count)
  }
  res_df <- data.frame(res_years, res_total)
  colnames(res_df) <- c('years', res)
  yearly_df <- merge(yearly_df, res_df, by="years", all=TRUE)
  # yearly_df[is.na(yearly_df)] <- 0
  yearly_df[paste0(res,'_perc')] <- yearly_df[res] / yearly_df["total"]
  rm(i, res_tot_years, res_years, res_total, res_df)
}
rm(res)

yearly_df$years <- as.Date(paste0(yearly_df$years, '-1-1'), '%Y-%m-%d')

# PLOTS
theme_hist <- theme_bw() +
  theme(plot.title = element_text(size = rel(2)),legend.position="none",axis.text.x = element_text(angle = 45, hjust = 1))

hist_yearly <- ggplot(yearly_df, aes(years,total))
hist_yearly <- hist_yearly +
  geom_bar(stat="sum") +
  labs(title = "Total contracts by year",x='Signature year',y='Total contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist
ggsave(hist_yearly,file='./plots/hist_yearly.png',height=8.5,width=11)
rm(hist_yearly)

hist_response_environment <- ggplot(yearly_df, aes(years,response_environment_perc))
hist_response_environment <- hist_response_environment +
  geom_bar(stat="sum") +
  labs(title = "Contracts mentionning environment by year",x='Signature year',y='Percent of all contracts') +
  scale_x_date(labels = date_format("%Y"), breaks = date_breaks("5 year"), limits=c()) +
  theme_hist + scale_y_continuous(labels = percent)

# # “Local content” 
# # “Profits tax”
# # “Rent tax”
# body <- '{
#   "query": {
#     "filtered": {
#       "filter": {
#         "term": {"pdf_text_string": "environment"}
#       }
#     } 
#   },
#   "aggregations": {
#     "year_agg": {
#       "terms": {
#         "field": "signature_year",
#         "size": 0
#       }
#     }
#   }
# }'

# query_list[['env_yearly_total']] <- '{
#   "query": {
#     "filtered": {
#       "filter": {
#         "bool": {
#           "must": [
#           {"term": {"signature_year": "%s"}},
#           {"term": {"pdf_text_string": "environment"}}
#         ]
#       }
#     }
#   }
# }
# }'


# # ETL
# yearly_total_contracts <- response_yearly_total$hits$total
# total_years <- length(response_yearly_total$aggregations$year_agg$buckets)
# years <- vector()
# total <- vector()
# for (i in 1:total.years) {
# 	years <- c(years,response$aggregations$year_agg$buckets[[i]]$key)
# 	total <- c(total,response$aggregations$year_agg$buckets[[i]]$doc_count)
# 	# print(response$aggregations$year_agg$buckets[[i]])
# }
# years <- as.Date(years, '%Y')
# yearly.hist <- data.frame(years, total)
# yearly.hist <- yearly.hist[order(years),]
# yearly.hist$years <- as.Date(yearly.hist$years,'%Y')
# rm(i,years,total)
