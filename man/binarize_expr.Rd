% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/compare_genelist.R
\name{binarize_expr}
\alias{binarize_expr}
\title{Binarize scRNAseq data}
\usage{
binarize_expr(mat, n = 1000, cut = 0)
}
\arguments{
\item{mat}{single-cell expression matrix}

\item{n}{number of top expressing genes to keep}

\item{cut}{cut off to set to 0}
}
\value{
matrix of 1s and 0s
}
\description{
Binarize scRNAseq data
}
\examples{
pbmc_avg <- average_clusters(
  mat = pbmc_matrix_small,
  cluster_info = pbmc_meta,
  cluster_col = "classified"
)

pbmc_avgb <- binarize_expr(pbmc_avg)
}
