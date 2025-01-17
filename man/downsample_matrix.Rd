% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{downsample_matrix}
\alias{downsample_matrix}
\title{downsample matrix by cluster or completely random}
\usage{
downsample_matrix(mat, n = 1, keep_cluster_proportions = TRUE,
  cluster_info = NULL, cluster_col = "cluster", set_seed = NULL)
}
\arguments{
\item{mat}{expression matrix}

\item{n}{number per cluster or fraction to keep}

\item{keep_cluster_proportions}{whether to subsample}

\item{cluster_info}{data.frame or vector containing cluster assignments per cell.
Order must match column order in supplied matrix. If a data.frame
provide the cluster_col parameters.}

\item{cluster_col}{column in cluster_info with cluster number}

\item{set_seed}{random seed}
}
\value{
new smaller mat with less cell_id columns
}
\description{
downsample matrix by cluster or completely random
}
\examples{
mat1 <- downsample_matrix(
  mat = pbmc_matrix_small,
  cluster_info = pbmc_meta$classified,
  n = 10,
  keep_cluster_proportions = TRUE,
  set_seed = 41
)
}
