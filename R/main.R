#' Compare scRNA-seq data to bulk RNA-seq data.
#'
#' @export
clustify <- function(input, ...) {
  UseMethod("clustify", input)
}

#' @rdname clustify
#' @param input single-cell expression matrix or Seurat object
#' @param metadata cell cluster assignments, supplied as a vector or data.frame.
#'   If data.frame is supplied then `cluster_col` needs to be set. Not required
#'   if running correlation per cell.
#' @param ref_mat reference expression matrix
#' @param cluster_col column in metadata that contains cluster ids per cell.
#'   Will default to first column of metadata if not supplied. Not required if
#'   running correlation per cell.
#' @param query_genes A vector of genes of interest to compare. If NULL, then
#'   common genes between the expr_mat and ref_mat will be used for comparision.
#' @param per_cell if true run per cell, otherwise per cluster.
#' @param n_perm number of permutations, set to 0 by default
#' @param compute_method method(s) for computing similarity scores
#' @param use_var_genes if providing a seurat object, use the variable genes
#'   (stored in seurat_object@var.genes) as the query_genes.
#' @param dr stored dimension reduction
#' @param seurat_out output cor matrix or called seurat object
#' @param verbose whether to report certain variables chosen
#' @param lookuptable if not supplied, will look in built-in table for object parsing
#' @param rm0 consider 0 as missing data, recommended for per_cell
#' @param obj_out whether to output object instead of cor matrix
#' @param rename_prefix prefix to add to type and r column names
#' @param threshold identity calling minimum correlation score threshold, only used when obj_out = T
#' @param ... additional arguments to pass to compute_method function
#'
#' @return matrix of correlation values, clusters from input as row names, cell
#'   types from ref_mat as column names
#'   
#' @examples
#' # Annotate a matrix and metadata
#' clustify(
#'   input = pbmc_matrix_small,
#'   metadata = pbmc_meta,
#'   ref_mat = pbmc_bulk_matrix,
#'   query_genes = pbmc_vargenes,
#'   cluster_col = "classified",
#'   verbose = TRUE
#' )
#'
#' # Annotate using a different method
#' res <- clustify(
#'   input = pbmc_matrix_small,
#'   metadata = pbmc_meta,
#'   ref_mat = pbmc_bulk_matrix,
#'   query_genes = pbmc_vargenes,
#'   cluster_col = "classified",
#'   compute_method = "cosine"
#' )
#'
#' # Annotate a Seurat object
#' clustify(
#'   s_small,
#'   pbmc_bulk_matrix,
#'   cluster_col = "res.1",
#'   seurat_out = TRUE,
#'   per_cell = FALSE,
#'   dr = "tsne"
#' )
#'
#' # Annotate (and return) a Seurat object per-cell
#' res <- clustify(
#'   input = s_small,
#'   ref_mat = pbmc_bulk_matrix,
#'   cluster_col = "res.1",
#'   seurat_out = TRUE,
#'   per_cell = TRUE,
#'   dr = "tsne"
#' )
#' @export
clustify.default <- function(input,
                             ref_mat,
                             metadata = NULL,
                             cluster_col = NULL,
                             query_genes = NULL,
                             per_cell = FALSE,
                             n_perm = 0,
                             compute_method = "spearman",
                             verbose = FALSE,
                             lookuptable = NULL,
                             rm0 = FALSE,
                             obj_out = FALSE,
                             rename_prefix = NULL,
                             threshold = 0,
                             ...) {
  if (!compute_method %in% clustifyr_methods) {
    stop(paste(compute_method, "correlation method not implemented"), call. = FALSE)
  }
  
  if (!inherits(input, c("matrix", "Matrix", "data.frame"))) {
    input_original <- input
    temp <- parse_loc_object(input,
      type = class(input),
      expr_loc = NULL,
      meta_loc = NULL,
      var_loc = NULL,
      cluster_col = cluster_col,
      lookuptable = lookuptable
    )
    
    if (!(is.null(temp[["expr"]]))) {
      message(paste0("recognized object type - ", class(input)))
    }
    
    input <- temp[["expr"]]
    metadata <- temp[["meta"]]
    if (is.null(query_genes)) {
      query_genes <- temp[["var"]]
    }
    
    if (is.null(cluster_col)) {
      cluster_col <- temp[["col"]]
    }
  }
  
  if (is.null(metadata) && !per_cell) {
    stop("`metadata` needed for per cluster analysis", call. = FALSE)
  }
  
  if (!is.null(cluster_col) && !cluster_col %in% colnames(metadata)) {
    stop("given `cluster_col` is not a column in `metadata`", call. = FALSE)
  }

  if (length(query_genes) == 0) {
    message("var.features not found, using all genes instead")
    query_genes <- NULL
  }
  
  expr_mat <- input

  # select gene subsets
  gene_constraints <- get_common_elements(
    rownames(expr_mat),
    rownames(ref_mat),
    query_genes
  )

  if (verbose) {
    message(paste0("using # of genes: ", length(gene_constraints)))
    if (length(gene_constraints) >= 10000) {
      message("using a high number genes to calculate correlation, please consider feature selection to improve performance")
    }
  }

  expr_mat <- expr_mat[gene_constraints, , drop = FALSE]
  ref_mat <- ref_mat[gene_constraints, , drop = FALSE]

  if (!per_cell) {
    if (is.vector(metadata)) {
      cluster_ids <- metadata
    } else if (is.factor(metadata)) {
      cluster_ids <- as.character(metadata)
    } else if (is.data.frame(metadata) & !is.null(cluster_col)) {
      cluster_ids <- metadata[[cluster_col]]
    } else {
      stop("metadata not formatted correctly,
           supply either a character vector or a dataframe", call. = FALSE)
    }
    if (class(cluster_ids) == "factor") {
      cluster_ids <- as.character(cluster_ids)
    }
    cluster_ids[is.na(cluster_ids)] <- "orig.NA"
  }

  if (per_cell) {
    cluster_ids <- colnames(expr_mat)
  }

  if (n_perm == 0) {
    res <- get_similarity(
      expr_mat,
      ref_mat,
      cluster_ids = cluster_ids,
      per_cell = per_cell,
      compute_method = compute_method,
      rm0 = rm0,
      ...
    )
  } else {
    # run permutation
    res <- permute_similarity(
      expr_mat,
      ref_mat,
      cluster_ids = cluster_ids,
      n_perm = n_perm,
      per_cell = per_cell,
      compute_method = compute_method,
      rm0 = rm0,
      ...
    )
  }

  if (obj_out && !inherits(input_original, c("matrix", "Matrix", "data.frame"))) {
    df_temp <- cor_to_call(
      res,
      metadata = metadata,
      cluster_col = cluster_col,
      threshold = threshold
    )
    
    df_temp_full <- call_to_metadata(
      df_temp,
      metadata = metadata,
      cluster_col = cluster_col,
      per_cell = per_cell,
      rename_prefix = rename_prefix
    )
    
    out <- insert_meta_object(
      input_original, 
      df_temp_full, 
      lookuptable = lookuptable
    )
    
    return(out)
  } else {
    return(res)
  }
}

#' @rdname clustify
#' @param ref_mat reference expression matrix
#' @param cluster_col column in metadata that contains cluster ids per cell. Will default to first
#' column of metadata if not supplied. Not required if running correlation per cell.
#' @param query_genes A vector of genes of interest to compare. If NULL, then common genes between
#' the expr_mat and ref_mat will be used for comparision.
#' @param per_cell if true run per cell, otherwise per cluster.
#' @param n_perm number of permutations, set to 0 by default
#' @param compute_method method(s) for computing similarity scores
#' @param use_var_genes if providing a seurat object, use the variable genes
#'  (stored in seurat_object@var.genes) as the query_genes.
#' @param dr stored dimension reduction
#' @param seurat_out output cor matrix or called seurat object
#' @param threshold identity calling minimum correlation score threshold
#' @param verbose whether to report certain variables chosen
#' @param rm0 consider 0 as missing data, recommended for per_cell
#' @param rename_prefix prefix to add to type and r column names
#' @param ... additional arguments to pass to compute_method function
#'
#' @return seurat2 object with type assigned in metadata, or matrix of
#'   correlation values, clusters from input as row names, cell types from
#'   ref_mat as column names
#'
#' @export
clustify.seurat <- function(input,
                            ref_mat,
                            cluster_col = NULL,
                            query_genes = NULL,
                            per_cell = FALSE,
                            n_perm = 0,
                            compute_method = "spearman",
                            use_var_genes = TRUE,
                            dr = "umap",
                            seurat_out = TRUE,
                            threshold = 0,
                            verbose = FALSE,
                            rm0 = FALSE,
                            rename_prefix = NULL,
                            ...) {
  s_object <- input
  # for seurat < 3.0
  expr_mat <- s_object@data
  metadata <- seurat_meta(s_object, dr = dr)

  if (use_var_genes && is.null(query_genes)) {
    query_genes <- s_object@var.genes
  }

  res <- clustify(
    expr_mat,
    ref_mat,
    metadata,
    query_genes,
    per_cell = per_cell,
    n_perm = n_perm,
    cluster_col = cluster_col,
    compute_method = compute_method,
    verbose = verbose,
    rm0 = rm0,
    ...
  )

  if (n_perm != 0) {
    res <- -log(res$p_val + .01, 10)
  }

  if (!seurat_out) {
    res
  } else {
    df_temp <- cor_to_call(
      res,
      metadata = metadata,
      cluster_col = cluster_col,
      threshold = threshold
    )

    df_temp_full <- call_to_metadata(
      df_temp,
      metadata = metadata,
      cluster_col = cluster_col,
      per_cell = per_cell,
      rename_prefix = rename_prefix
    )

    if ("Seurat" %in% loadedNamespaces()) {
      s_object@meta.data <- df_temp_full
      return(s_object)
    } else {
      message("seurat not loaded, returning cor_mat instead")
      return(res)
    }
    s_object
  }
}

#' @rdname clustify
#' @param ref_mat reference expression matrix
#' @param cluster_col column in metadata that contains cluster ids per cell. Will default to first
#' column of metadata if not supplied. Not required if running correlation per cell.
#' @param query_genes A vector of genes of interest to compare. If NULL, then common genes between
#' the expr_mat and ref_mat will be used for comparision.
#' @param per_cell if true run per cell, otherwise per cluster.
#' @param n_perm number of permutations, set to 0 by default
#' @param compute_method method(s) for computing similarity scores
#' @param use_var_genes if providing a seurat object, use the variable genes
#'  (stored in seurat_object@var.genes) as the query_genes.
#' @param dr stored dimension reduction
#' @param seurat_out output cor matrix or called seurat object
#' @param threshold identity calling minimum correlation score threshold
#' @param verbose whether to report certain variables chosen
#' @param rm0 consider 0 as missing data, recommended for per_cell
#' @param rename_prefix prefix to add to type and r column names
#' @param ... additional arguments to pass to compute_method function
#' 
#' @return seurat3 object with type assigned in metadata, or matrix of
#'   correlation values, clusters from input as row names, cell types from
#'   ref_mat as column names
#'   
#' @export
clustify.Seurat <- function(input,
                            ref_mat,
                            cluster_col = NULL,
                            query_genes = NULL,
                            per_cell = FALSE,
                            n_perm = 0,
                            compute_method = "spearman",
                            use_var_genes = TRUE,
                            dr = "umap",
                            seurat_out = TRUE,
                            threshold = 0,
                            verbose = FALSE,
                            rm0 = FALSE,
                            rename_prefix = NULL,
                            ...) {
  s_object <- input
  # for seurat 3.0 +
  expr_mat <- s_object@assays$RNA@data
  metadata <- seurat_meta(s_object, dr = dr)

  if (use_var_genes && is.null(query_genes)) {
    query_genes <- s_object@assays$RNA@var.features
  }

  res <- clustify(
    expr_mat,
    ref_mat,
    metadata,
    query_genes,
    per_cell = per_cell,
    n_perm = n_perm,
    cluster_col = cluster_col,
    compute_method = compute_method,
    verbose = verbose,
    rm0 = rm0,
    ...
  )
  
  if (n_perm != 0) {
    res <- -log(res$p_val + .01, 10)
  }

  if (!seurat_out) {
    res
  } else {
    df_temp <- cor_to_call(
      res,
      metadata = metadata,
      cluster_col = cluster_col,
      threshold = threshold
    )

    df_temp_full <- call_to_metadata(
      df_temp,
      metadata = metadata,
      cluster_col = cluster_col,
      per_cell = per_cell,
      rename_prefix = rename_prefix
    )

    if ("Seurat" %in% loadedNamespaces()) {
      s_object@meta.data <- df_temp_full
      return(s_object)
    } else {
      message("seurat not loaded, returning cor_mat instead")
      return(res)
    }
    s_object
  }
}
#' Correlation functions available in clustifyr
#' @export
clustifyr_methods <- c(
  "pearson",
  "spearman",
  "cosine",
  "kl_divergence"
)

#' Main function to compare scRNA-seq data to gene lists.
#'
#' @export
clustify_lists <- function(input, ...) {
  UseMethod("clustify_lists", input)
}

#' @rdname clustify_lists
#' @param input single-cell expression matrix or Seurat object
#' @param marker matrix or dataframe of candidate genes for each cluster
#' @param marker_inmatrix whether markers genes are already in preprocessed matrix form
#' @param cluster_info data.frame or vector containing cluster assignments per cell.
#' Order must match column order in supplied matrix. If a data.frame
#' provide the cluster_col parameters.
#' @param cluster_col column in cluster_info with cluster number
#' @param if_log input data is natural log, averaging will be done on unlogged data
#' @param per_cell compare per cell or per cluster
#' @param topn number of top expressing genes to keep from input matrix
#' @param cut expression cut off from input matrix
#' @param genome_n number of genes in the genome
#' @param metric adjusted p-value for hypergeometric test, or jaccard index
#' @param output_high if true (by default to fit with rest of package),
#' -log10 transform p-value
#' @param lookuptable if not supplied, will look in built-in table for object parsing
#' @param obj_out whether to output object instead of cor matrix
#' @param rename_prefix prefix to add to type and r column names
#' @param threshold identity calling minimum correlation score threshold, only used when obj_out = T
#' @param ... passed to matrixize_markers
#' 
#' @return matrix of numeric values, clusters from input as row names, cell types from marker_mat as column names

#' @export
clustify_lists.default <- function(input,
                                   marker,
                                   marker_inmatrix = TRUE,
                                   cluster_info = NULL,
                                   cluster_col = NULL,
                                   if_log = TRUE,
                                   per_cell = FALSE,
                                   topn = 800,
                                   cut = 0,
                                   genome_n = 30000,
                                   metric = "hyper",
                                   output_high = TRUE,
                                   lookuptable = NULL,
                                   obj_out = FALSE,
                                   rename_prefix = NULL,
                                   threshold = 0,
                                   ...) {
  if (!inherits(input, c("matrix", "Matrix", "data.frame"))) {
    input_original <- input
    temp <- parse_loc_object(input,
      type = class(input),
      expr_loc = NULL,
      meta_loc = NULL,
      var_loc = NULL,
      cluster_col = cluster_col,
      lookuptable = lookuptable
    )
    input <- temp[["expr"]]
    metadata <- temp[["meta"]]
    cluster_info <- metadata
    if (is.null(cluster_col)) {
      cluster_col <- temp[["col"]]
    }
  }

  if (!(per_cell)) {
    input <- average_clusters(input,
      cluster_info,
      if_log = if_log,
      cluster_col = cluster_col
    )
  }

  bin_input <- binarize_expr(input, n = topn, cut = cut)

  if (marker_inmatrix != TRUE) {
    marker <- matrixize_markers(
      marker,
      ...
    )
  }

  res <- compare_lists(bin_input,
    marker_mat = marker,
    n = genome_n,
    metric = metric,
    output_high = output_high
  )
  
  if (obj_out && !inherits(input_original, c("matrix", "Matrix", "data.frame"))) {
    df_temp <- cor_to_call(
      res,
      metadata = metadata,
      cluster_col = cluster_col,
      threshold = threshold
    )
    
    df_temp_full <- call_to_metadata(
      df_temp,
      metadata = metadata,
      cluster_col = cluster_col,
      per_cell = per_cell,
      rename_prefix = rename_prefix
    )
    
    out <- insert_meta_object(
      input_original, 
      df_temp_full, 
      lookuptable = lookuptable
    )
    
    return(out)
  } else {
    return(res)
  }
}

#' @rdname clustify_lists
#' @param input seurat object
#' @param cluster_info data.frame or vector containing cluster assignments per cell.
#' Order must match column order in supplied matrix. If a data.frame
#' provide the cluster_col parameters.
#' @param cluster_col column in cluster_info with cluster number
#' @param if_log input data is natural log,
#' averaging will be done on unlogged data
#' @param per_cell compare per cell or per cluster
#' @param topn number of top expressing genes to keep from input matrix
#' @param cut expression cut off from input matrix
#' @param marker matrix or dataframe of candidate genes for each cluster
#' @param marker_inmatrix whether markers genes are already in preprocessed matrix form
#' @param genome_n number of genes in the genome
#' @param metric adjusted p-value for hypergeometric test, or jaccard index
#' @param output_high if true (by default to fit with rest of package),
#' -log10 transform p-value
#' @param dr stored dimension reduction
#' @param seurat_out output cor matrix or called seurat object
#' @param threshold identity calling minimum score threshold
#' @param rename_prefix prefix to add to type and r column names

#' @param ... passed to matrixize_markers
#' @return seurat2 object with type assigned in metadata, or matrix of numeric values, clusters from input as row names, cell types from marker_mat as column names
#' @export
clustify_lists.seurat <- function(input,
                                  cluster_info = NULL,
                                  cluster_col = NULL,
                                  if_log = TRUE,
                                  per_cell = FALSE,
                                  topn = 800,
                                  cut = 0,
                                  marker,
                                  marker_inmatrix = TRUE,
                                  genome_n = 30000,
                                  metric = "hyper",
                                  output_high = TRUE,
                                  dr = "umap",
                                  seurat_out = TRUE,
                                  threshold = 0,
                                  rename_prefix = NULL,
                                  ...) {
  s_object <- input
  # for seurat < 3.0
  input <- s_object@data
  cluster_info <- as.data.frame(seurat_meta(s_object, dr = dr))
  metadata <- cluster_info

  res <- clustify_lists(input,
    per_cell = per_cell,
    cluster_info = cluster_info,
    if_log = if_log,
    cluster_col = cluster_col,
    topn = topn,
    cut = cut,
    marker,
    marker_inmatrix = marker_inmatrix,
    genome_n = genome_n,
    metric = metric,
    output_high = output_high,
    ...
  )

  if (!seurat_out) {
    res
  } else {
    df_temp <- cor_to_call(
      res,
      metadata = metadata,
      cluster_col = cluster_col,
      threshold = threshold
    )

    df_temp_full <- call_to_metadata(
      df_temp,
      metadata = metadata,
      cluster_col = cluster_col,
      per_cell = per_cell,
      rename_prefix = rename_prefix
    )

    if ("Seurat" %in% loadedNamespaces()) {
      s_object@meta.data <- df_temp_full
      return(s_object)
    } else {
      message("seurat not loaded, returning cor_mat instead")
      return(res)
    }
    s_object
  }
}

#' @rdname clustify_lists
#' @param input seurat object
#' @param cluster_info data.frame or vector containing cluster assignments per cell.
#' Order must match column order in supplied matrix. If a data.frame
#' provide the cluster_col parameters.
#' @param cluster_col column in cluster_info with cluster number
#' @param if_log input data is natural log,
#' averaging will be done on unlogged data
#' @param per_cell compare per cell or per cluster
#' @param topn number of top expressing genes to keep from input matrix
#' @param cut expression cut off from input matrix
#' @param marker matrix or dataframe of candidate genes for each cluster
#' @param marker_inmatrix whether markers genes are already in preprocessed matrix form
#' @param genome_n number of genes in the genome
#' @param metric adjusted p-value for hypergeometric test, or jaccard index
#' @param output_high if true (by default to fit with rest of package),
#' -log10 transform p-value
#' @param dr stored dimension reduction
#' @param seurat_out output cor matrix or called seurat object
#' @param threshold identity calling minimum score threshold
#' @param rename_prefix prefix to add to type and r column names
#' @param ... passed to matrixize_markers

#' @return seurat3 object with type assigned in metadata, or matrix of numeric values, clusters from input as row names, cell types from marker_mat as column names
clustify_lists.Seurat <- function(input,
                                  cluster_info = NULL,
                                  cluster_col = NULL,
                                  if_log = TRUE,
                                  per_cell = FALSE,
                                  topn = 800,
                                  cut = 0,
                                  marker,
                                  marker_inmatrix = TRUE,
                                  genome_n = 30000,
                                  metric = "hyper",
                                  output_high = TRUE,
                                  dr = "umap",
                                  seurat_out = TRUE,
                                  threshold = 0,
                                  rename_prefix = NULL,
                                  ...) {
  s_object <- input
  # for seurat 3.0 +
  input <- s_object@assays$RNA@data
  cluster_info <- as.data.frame(seurat_meta(s_object, dr = dr))
  metadata <- cluster_info

  res <- clustify_lists(input,
    per_cell = per_cell,
    cluster_info = cluster_info,
    if_log = if_log,
    cluster_col = cluster_col,
    topn = topn,
    cut = cut,
    marker,
    marker_inmatrix = marker_inmatrix,
    genome_n = genome_n,
    metric = metric,
    output_high = output_high,
    ...
  )

  if (!seurat_out) {
    res
  } else {
    df_temp <- cor_to_call(
      res,
      metadata = metadata,
      cluster_col = cluster_col,
      threshold = threshold
    )

    df_temp_full <- call_to_metadata(
      df_temp,
      metadata = metadata,
      cluster_col = cluster_col,
      per_cell = per_cell,
      rename_prefix = rename_prefix
    )

    if ("Seurat" %in% loadedNamespaces()) {
      s_object@meta.data <- df_temp_full
      return(s_object)
    } else {
      message("seurat not loaded, returning cor_mat instead")
      return(res)
    }
    s_object
  }
}
