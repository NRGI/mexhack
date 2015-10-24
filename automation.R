library(elastic)
library(ggplot2)
library(scales)
connect(es_base = "https://search-rc-elasticsearch-cluster-zhtfwjechy4noqdtqablbofcxi.us-east-1.es.amazonaws.com", es_port = "")
theme.hist <- theme_bw() + theme(plot.title = element_text(size = rel(2)),legend.position="none",axis.text.x = element_text(angle = 45, hjust = 1))

type <- 'master'
index <-'rc_nrgi1'
# year <- 2000
# language <- 'en'
# all contracts
body <- '{
  "aggregations": {
    "year_agg": {
      "terms": {
        "field": "signature_year",
        "size": 0
      }
    }
  }
}'
response <- Search(index=index, type=type, body=body)
rm(body)
total.contracts <- response$hits$total
total.years <- length(response$aggregations$year_agg$buckets)
years <- vector()
total <- vector()
for (i in 1:total.years) {
	years <- c(years,response$aggregations$year_agg$buckets[[i]]$key)
	total <- c(total,response$aggregations$year_agg$buckets[[i]]$doc_count)
	# print(response$aggregations$year_agg$buckets[[i]])
}
years <- as.Date(years)
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