% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{clustify_intra}
\alias{clustify_intra}
\title{Intra-experiment cluster projection for one sample/set to the rest}
\usage{
clustify_intra(expr_mat, metadata, query_genes, cluster_col, sample_col,
  sample_id, per_cell = FALSE, compute_method = "spearman", ...)
}
\arguments{
\item{expr_mat}{single-cell expression matrix or Seurat object}

\item{metadata}{cell cluster assignments, supplied as a vector or data.frame. If
data.frame is supplied then \code{cluster_col} needs to be set. Not required if running correlation per cell.}

\item{query_genes}{A vector of genes of interest to compare. If NULL, then common genes between
the expr_mat and ref_mat will be used for comparision.}

\item{cluster_col}{column in metadata that contains cluster ids per cell. Will default to first
column of metadata if not supplied. Not required if running correlation per cell.}

\item{sample_col}{column in metadata that contains sample/subset info}

\item{sample_id}{ids in column to serve as reference}

\item{per_cell}{if true run per cell, otherwise per cluster.}

\item{compute_method}{method(s) for computing similarity scores}

\item{...}{additional arguments to pass to compute_method function}
}
\value{
matrix of correlation values, clusters as row names and column names
}
\description{
Intra-experiment cluster projection for one sample/set to the rest
}
\examples{
pbmc_meta2 <- pbmc_meta

pbmc_meta2$sample <- c(
  rep("A", 1319),
  rep("B", 1319)
)

pbmc_meta2$classified <- c(
  pbmc_meta2$classified[1:1319],
  pbmc_meta2$classified[1320:2638]
)

res <- clustify_intra(
  expr_mat = pbmc_matrix_small,
  metadata = pbmc_meta2,
  query_genes = pbmc_vargenes,
  cluster_col = "classified",
  sample_col = "sample",
  sample_id = "A"
)
}
