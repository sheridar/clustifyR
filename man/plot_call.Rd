% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot.R
\name{plot_call}
\alias{plot_call}
\title{Plot called clusters on a tSNE or umap, for each reference cluster given}
\usage{
plot_call(cor_matrix, metadata, data_to_plot = colnames(cor_matrix), ...)
}
\arguments{
\item{cor_matrix}{input similarity matrix}

\item{metadata}{input metadata with tsne or umap coordinates and cluster ids}

\item{data_to_plot}{colname of data to plot, defaults to all}

\item{...}{passed to plot_tsne}
}
\value{
list of ggplot object, cells projected by dr, colored by cell type classification
}
\description{
Plot called clusters on a tSNE or umap, for each reference cluster given
}
\examples{
res <- clustify(
  input = pbmc_matrix_small,
  metadata = pbmc_meta,
  ref_mat = pbmc_bulk_matrix,
  query_genes = pbmc_vargenes,
  cluster_col = "classified"
)

plts <- plot_call(
  cor_matrix = res,
  metadata = pbmc_meta,
  data_to_plot = colnames(res)[1:2],
  cluster_col = "classified"
)

plts
}
