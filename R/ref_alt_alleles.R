# Compute the ref and alt alleles of a tidy dataset

#' @name ref_alt_alleles

#' @title **deprecated** use \code{\link[stackr]{change_alleles}}

#' @description compute the REF and ALT alleles from a biallelic
#' genomic tidy data frame.
#' Used internally in \href{https://github.com/thierrygosselin/stackr}{stackr} 
#' and might be of interest for users.
#' 
#' @param data A biallelic genomic data set in the working directory or 
#' object in the global environment in wide or long (tidy) formats. 
#' See details for more info. 

#' @param monomorphic.out (optional) Should the monomorphic 
#' markers present in the dataset be filtered out ? 
#' Default: \code{monomorphic.out = TRUE}.

#' @return A tidy data frame with 6 columns: 
#' \code{MARKERS, INDIVIDUALS, REF, ALT, GT_VCF, GT_BIN}.
#' \code{GT_VCF}: the genotype in VCF format
#' \code{GT_BIN}: coding used internally to easily convert to genlight, 
#' the coding \code{0, 1, 2, NA} stands for the number of ALT allele in the 
#' genotype and \code{NA} for missing genotype.

#' @details \strong{Input data:}
#'  
#' To discriminate the long from the wide format, 
#' the function \pkg{stackr} \code{\link[stackr]{tidy_wide}} searches 
#' for \code{MARKERS or LOCUS} in column names (TRUE = long format).
#' The data frame is tab delimitted.

#' \strong{Wide format:}
#' The wide format cannot store metadata info.
#' The wide format starts with these 2 id columns: 
#' \code{INDIVIDUALS}, \code{POP_ID} (that refers to any grouping of individuals), 
#' the remaining columns are the markers in separate columns storing genotypes.
#' 
#' \strong{Long/Tidy format:}
#' The long format is considered to be a tidy data frame and can store metadata info. 
#' (e.g. from a VCF see \pkg{stackr} \code{\link{tidy_genomic_data}}). A minimum of 4 columns
#' are required in the long format: \code{INDIVIDUALS}, \code{POP_ID}, 
#' \code{MARKERS or LOCUS} and \code{GENOTYPE or GT}. The rest are considered metata info.
#' 
#' \strong{2 genotypes formats are available:}
#' 6 characters no separator: e.g. \code{001002 of 111333} (for heterozygote individual).
#' 6 characters WITH separator: e.g. \code{001/002 of 111/333} (for heterozygote individual).
#' The separator can be any of these: \code{"/", ":", "_", "-", "."}.
#' 
#' \emph{How to get a tidy data frame ?}
#' \pkg{stackr} \code{\link{tidy_genomic_data}} can transform 6 genomic data formats 
#' in a tidy data frame.


#' @export
#' @rdname ref_alt_alleles
#' @importFrom dplyr select mutate group_by ungroup rename tally filter if_else arrange summarise top_n distinct coalesce if_else full_join
#' @importFrom stringi stri_replace_all_fixed stri_join stri_sub
#' @importFrom data.table fread
#' @importFrom tibble has_name
#' @importFrom tidyr spread gather
#' @importFrom purrr flatten_chr

#' @author Thierry Gosselin \email{thierrygosselin@@icloud.com}

ref_alt_alleles <- function(data, monomorphic.out = TRUE) {
  
  # Checking for missing and/or default arguments ------------------------------
  if (missing(data)) stop("Input file missing")
  
  input <- data
  
  # check genotype column naming
  if (tibble::has_name(input, "GENOTYPE")) {
    colnames(input) <- stringi::stri_replace_all_fixed(
      str = colnames(input), 
      pattern = "GENOTYPE", 
      replacement = "GT", 
      vectorize_all = FALSE)
  }
  
  # necessary steps to make sure we work with unique markers and not duplicated LOCUS
  if (tibble::has_name(input, "LOCUS") && !tibble::has_name(input, "MARKERS")) {
    input <- dplyr::rename(.data = input, MARKERS = LOCUS)
  }
  
  # Detecting biallelic markers and removing monomorphic markers ---------------
  input.genotyped.split <- dplyr::select(.data = input, MARKERS, POP_ID, INDIVIDUALS, GT) %>% 
    dplyr::filter(GT != "000000") %>% 
    dplyr::mutate(
      A1 = stringi::stri_sub(str = GT, from = 1, to = 3),
      A2 = stringi::stri_sub(str = GT, from = 4, to = 6)
    ) %>% 
    dplyr::select(-GT) %>%
    tidyr::gather(data = ., key = ALLELES_GROUP, value = ALLELES, -c(MARKERS, INDIVIDUALS, POP_ID))
  
  alleles.old <- dplyr::distinct(.data = input.genotyped.split, MARKERS, ALLELES) %>% 
    dplyr::arrange(MARKERS, ALLELES)

  marker.type <- dplyr::distinct(.data = input.genotyped.split, MARKERS, ALLELES) %>%
    dplyr::count(x = ., MARKERS)

  # monomorphic
  if (monomorphic.out) { 
    # monomorphic markers 
    mono.markers <-  dplyr::filter(.data = marker.type, n == 1) %>% 
      dplyr::select(MARKERS)
  }
  
  # Biallelic marker detection -------------------------------------------------
  biallelic <- purrr::flatten_chr(.x = dplyr::summarise(.data = marker.type, BIALLELIC = max(n, na.rm = TRUE)))
  
  if (biallelic > 4 ) {
    biallelic <- FALSE
  } else {
    biallelic <- TRUE
  }
  
  marker.type <- NULL
  
  # Function to calculate REF\ALT --------------------------------------------
  ref_compute <- function(data, new.ref) {
    input <- data %>%
      dplyr::mutate(
        A1 = stringi::stri_sub(str = GT, from = 1, to = 3),
        A2 = stringi::stri_sub(str = GT, from = 4, to = 6)
      ) %>% 
      dplyr::full_join(new.ref, by = "MARKERS") %>%
      dplyr::mutate(
        A1 = replace(A1, which(A1 == "000"), NA),
        A2 = replace(A2, which(A2 == "000"), NA),
        GT_VCF_A1 = dplyr::if_else(A1 == REF, "0", "1", missing = "."),
        GT_VCF_A2 = dplyr::if_else(A2 == REF, "0", "1", missing = "."),
        GT_VCF = stringi::stri_join(GT_VCF_A1, GT_VCF_A2, sep = "/"),
        GT_BIN = stringi::stri_replace_all_fixed(
          str = GT_VCF, 
          pattern = c("0/0", "1/1", "0/1", "1/0", "./."), 
          replacement = c("0", "2", "1", "1", NA), 
          vectorize_all = FALSE
        ),
        REF = stringi::stri_replace_all_fixed(
          str = REF, 
          pattern = c("001", "002", "003", "004"), 
          replacement = c("A", "C", "G", "T"),
          vectorize_all = FALSE),
        ALT = stringi::stri_replace_all_fixed(
          str = ALT, 
          pattern = c("001", "002", "003", "004"), 
          replacement = c("A", "C", "G", "T"),
          vectorize_all = FALSE)
      ) %>% 
      dplyr::select(-c(A1, A2, GT_VCF_A1, GT_VCF_A2))
  }#End ref_compute
  
  
  # Detection and change -------------------------------------------------------
  if (biallelic) {
    alleles.new.ref <- dplyr::select(.data = input.genotyped.split, MARKERS, ALLELES) %>%
      dplyr::count(x = ., MARKERS, ALLELES) %>%
      dplyr::group_by(MARKERS) %>%
      dplyr::top_n(1, n) %>% 
      dplyr::distinct(MARKERS, .keep_all = TRUE) %>% 
      dplyr::mutate(REF = rep("REF", n())) %>% 
      dplyr::select(-n) %>% 
      dplyr::full_join(alleles.old, by = c("MARKERS", "ALLELES")) %>% 
      dplyr::mutate(REF = dplyr::coalesce(REF, "ALT")) %>% # faster than stri_replace_na
      dplyr::group_by(MARKERS) %>% 
      tidyr::spread(data = ., key = REF, value = ALLELES) %>% 
      dplyr::mutate(ALT = dplyr::if_else(is.na(ALT), REF, ALT))
    
    alleles.old <- NULL
    
    if (tibble::has_name(input, "REF")) {
      change.ref <- dplyr::distinct(.data = input, MARKERS, REF, ALT) %>% 
        dplyr::full_join(
          alleles.new.ref %>% 
            dplyr::select(MARKERS, REF_NEW = REF)
          , by = "MARKERS") %>% 
        dplyr::mutate(
          REF_NEW = stringi::stri_replace_all_fixed(
            str = REF_NEW, 
            pattern = c("001", "002", "003", "004"), 
            replacement = c("A", "C", "G", "T"),
            vectorize_all = FALSE),
          CHANGE = dplyr::if_else(REF == REF_NEW, "identical", "different")
        ) %>%
        dplyr::filter(CHANGE == "different") %>% 
        dplyr::select(MARKERS) %>% 
        purrr::flatten_chr(.)
      
      message(stringi::stri_join("Number of markers with REF/ALT change = ", length(change.ref)))
      
      # switch ALLELE_REF_DEPTH/ALLELE_ALT_DEPTH
      if (length(change.ref) > 0 & tibble::has_name(input, "ALLELE_REF_DEPTH")) {
        input <- input %>% 
          dplyr::mutate(
            ALLELE_REF_DEPTH_NEW = dplyr::if_else(MARKERS %in% change.ref, ALLELE_ALT_DEPTH, ALLELE_REF_DEPTH),
            ALLELE_ALT_DEPTH_NEW = dplyr::if_else(MARKERS %in% change.ref, ALLELE_REF_DEPTH, ALLELE_ALT_DEPTH)
          ) %>%
          dplyr::select(-ALLELE_REF_DEPTH, -ALLELE_ALT_DEPTH) %>% 
          dplyr::rename(ALLELE_REF_DEPTH = ALLELE_REF_DEPTH_NEW, ALLELE_ALT_DEPTH = ALLELE_ALT_DEPTH_NEW)
      }
      
      # switch REF/ALT in the dataset
      if (length(change.ref) > 0) {
        input <- dplyr::select(input, -c(REF, ALT))
        input <- ref_compute(data = input, new.ref = alleles.new.ref)
      }
      
    } else {
      input <- ref_compute(data = input, new.ref = alleles.new.ref)
    }
    
    # monomorphic filter
    if (monomorphic.out) {
      if (dplyr::n_distinct(mono.markers$MARKERS) > 0) {
        input <- dplyr::filter(input, !MARKERS %in% mono.markers$MARKERS)
      }
    }
  } else {
    message("Data is not biallellic")
    input <- input
  }
  res <- list(input = input, biallelic = biallelic)
  return(res)
}#End ref_alt_alleles
