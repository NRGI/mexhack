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

# test <- require()
# if(test == FALSE) install.packages("")
# require

connect(es_base = "https://search-rc-elasticsearch-cluster-zhtfwjechy4noqdtqablbofcxi.us-east-1.es.amazonaws.com", es_port = "")
theme_hist <- theme_bw() + theme(plot.title = element_text(size = rel(2)),legend.position="none",axis.text.x = element_text(angle = 45, hjust = 1))
# BASE SETTINGS
type <- 'master'
index <-'rc_nrgi1'

# QUERY BUILDER
query_list <- list()
basic_search_term_vecor <- c('environment', 'consent', 'resettlement', 'consultation', 'arbitration', 'renegotiation', 'confidentiality')
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
for(term in basic_search_term_vecor) {
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


# API CALL
response_list <- list()
for (i in names(query_list)) {
  response_list[[paste('response_', i, sep='')]] <- Search(index=index, type=type, body=query_list[[i]])
}
# ETL
yearly_total_contracts <- response_list[["response_yearly_total"]]$hits$total
total_years <- length(response_list[["response_yearly_total"]]$aggregations$year_agg$buckets)
years <- vector()
total <- vector()
for (i in 1:total_years) {
  years <- c(years,response_list[["response_yearly_total"]]$aggregations$year_agg$buckets[[i]]$key)
  total <- c(total,response_list[["response_yearly_total"]]$aggregations$year_agg$buckets[[i]]$doc_count)
  # print(response$aggregations$year_agg$buckets[[i]])
}
years <- as.Date(paste0(years, '-1-1'), '%Y')
yearly_hist <- data.frame(years, total)

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




# ETL
yearly_total_contracts <- response_yearly_total$hits$total
total_years <- length(response_yearly_total$aggregations$year_agg$buckets)
years <- vector()
total <- vector()
for (i in 1:total.years) {
	years <- c(years,response$aggregations$year_agg$buckets[[i]]$key)
	total <- c(total,response$aggregations$year_agg$buckets[[i]]$doc_count)
	# print(response$aggregations$year_agg$buckets[[i]])
}
years <- as.Date(years, '%Y')
yearly.hist <- data.frame(years, total)
yearly.hist <- yearly.hist[order(years),]
yearly.hist$years <- as.Date(yearly.hist$years,'%Y')
rm(i,years,total)

plot.yearly.hist <- ggplot(yearly.hist, aes(years,total))
plot.yearly.hist <- plot.yearly.hist +
	geom_bar(stat="sum") +
	theme.hist +
	labs(title = "ResourceContracts.org contracts by year",x='Signature year',y='Total contracts') +
	scale_x_date(labels = date_format("%Y"), breaks = date_breaks("year"))