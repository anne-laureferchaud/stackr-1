# write an Arlequin file from a tidy data frame

#' @name write_arlequin
#' @title Write an arlequin file from a tidy data frame
#' @description Write a arlequin file from a tidy data frame.
#' Used internally in \href{https://github.com/thierrygosselin/stackr}{stackr} 
#' and \href{https://github.com/thierrygosselin/assigner}{assigner}
#' and might be of interest for users.

#' @param data A tidy data frame object in the global environment or
#' a tidy data frame in wide or long format in the working directory.
#' \emph{How to get a tidy data frame ?}
#' Look into \pkg{stackr} \code{\link{tidy_genomic_data}}.

#' @param pop.levels (optional, string) A character string with your populations ordered.
#' Default: \code{pop.levels = NULL}.

#' @param filename (optional) The file name prefix for the arlequin file 
#' written to the working directory. With default: \code{filename = NULL}, 
#' the date and time is appended to \code{stackr_arlequin_}.

#' @param ... other parameters passed to the function.

#' @return An arlequin file is saved to the working directory. 

#' @references Excoffier, L.G. Laval, and S. Schneider (2005) 
#' Arlequin ver. 3.0: An integrated software package for population genetics 
#' data analysis. Evolutionary Bioinformatics Online 1:47-50.

#' @export
#' @rdname write_arlequin
#' @importFrom dplyr select distinct n_distinct group_by ungroup rename arrange tally filter if_else mutate summarise left_join inner_join right_join anti_join semi_join full_join
#' @importFrom stringi stri_join stri_replace_all_fixed stri_extract_all_fixed stri_replace_all_regex stri_sub stri_pad_left stri_count_fixed stri_replace_na 
#' @importFrom tibble has_name
#' @importFrom tidyr spread gather separate

#' @author Thierry Gosselin \email{thierrygosselin@@icloud.com}


write_arlequin <- function(
  data,
  pop.levels = NULL, 
  filename = NULL,
  ...
) {
  
  # Checking for missing and/or default arguments ******************************
  if (missing(data)) stop("Input file necessary to write the arlequin file is missing")
  
  # Import data ---------------------------------------------------------------
  if (is.vector(data)) {
    input <- stackr::tidy_wide(data = data, import.metadata = FALSE)
  } else {
    input <- data
  }
  
  # check genotype column naming
  colnames(input) <- stringi::stri_replace_all_fixed(
    str = colnames(input), 
    pattern = "GENOTYPE", 
    replacement = "GT", 
    vectorize_all = FALSE
  )
  
  # necessary steps to make sure we work with unique markers and not duplicated LOCUS
  if (tibble::has_name(input, "LOCUS") && !tibble::has_name(input, "MARKERS")) {
    input <- dplyr::rename(.data = input, MARKERS = LOCUS)
  }
  
  input <- dplyr::select(.data = input, POP_ID, INDIVIDUALS, MARKERS, GT)

  
  # pop.levels -----------------------------------------------------------------
  if (!is.null(pop.levels)) {
    input <- dplyr::mutate(
      .data = input,
      POP_ID = factor(POP_ID, levels = pop.levels, ordered = TRUE),
      POP_ID = droplevels(POP_ID)
    ) %>% 
      dplyr::arrange(POP_ID, INDIVIDUALS, MARKERS)
  } else {
    input <- dplyr::mutate(.data = input, POP_ID = factor(POP_ID)) %>% 
      dplyr::arrange(POP_ID, INDIVIDUALS, MARKERS)
  }
  
  # Create a marker vector  ------------------------------------------------
  markers <- dplyr::distinct(.data = input, MARKERS) %>%
    dplyr::arrange(MARKERS) %>%
    purrr::flatten_chr(.)
  npop <- length(unique(input$POP_ID))
  
  # arlequin format ----------------------------------------------------------------
  input <- input %>%
    tidyr::separate(col = GT, into = c("A1", "A2"), sep = 3, extra = "drop", remove = TRUE) %>%
    tidyr::gather(data = ., key = ALLELES, value = GT, -c(POP_ID, INDIVIDUALS, MARKERS)) %>% 
    dplyr::mutate(
      GT = stringi::stri_replace_all_fixed(str = GT, pattern = "000", replacement = "-9", vectorize_all = FALSE)
    ) %>%
    dplyr::select(INDIVIDUALS, POP_ID, MARKERS, ALLELES, GT) %>% 
    tidyr::spread(data = ., key = MARKERS, value = GT) %>% 
    dplyr::select(-ALLELES) %>% 
    dplyr::arrange(POP_ID, INDIVIDUALS)
  
  # Write the file in arlequin format -----------------------------------------
  
  # Filename
  if (is.null(filename)) {
    # Get date and time to have unique filenaming
    file.date <- stringi::stri_replace_all_fixed(Sys.time(), pattern = " EDT", replacement = "", vectorize_all = FALSE)
    file.date <- stringi::stri_replace_all_fixed(file.date, pattern = c("-", " ", ":"), replacement = c("", "@", ""), vectorize_all = FALSE)
    file.date <- stringi::stri_sub(file.date, from = 1, to = 13)
    filename <- stringi::stri_join("stackr_arlequin_", file.date, ".arp")
  } else {
    filename <- stringi::stri_join(filename, ".arp")
  }
  
  filename.connection <- file(filename, "w") # open the connection to the file
  # Profile section
  write("[Profile]", file = filename.connection) 
  write(paste('Title = "stackr_arlequin_export', " ", file.date, '"'), file = filename.connection, append = TRUE) 
  write(paste("NbSamples = ", npop), file = filename.connection, append = TRUE) # number of pop
  write(paste("GenotypicData = 1"), file = filename.connection, append = TRUE)
  write(paste("LocusSeparator = WHITESPACE"), file = filename.connection, append = TRUE)
  write(paste("GameticPhase = 0"), file = filename.connection, append = TRUE) # 0 = unknown gametic phase
  write(paste("MissingData = '?'"), file = filename.connection, append = TRUE) 
  write(paste("DataType = STANDARD"), file = filename.connection, append = TRUE) 
  write(paste("[Data]"), file = filename.connection, append = TRUE)
  write(paste("[[Samples]]"), file = filename.connection, append = TRUE)
  
  pop <- input$POP_ID # Create a population vector
  input.split <- split(input, pop) # split genepop by populations
  for (i in 1:length(input.split)) {
    # i <- 1
    pop.data <- input.split[[i]]
    pop.name <- unique(pop.data$POP_ID)
    n.ind <- dplyr::n_distinct(pop.data$INDIVIDUALS)
    write(paste("SampleName = ", pop.name), file = filename.connection, append = TRUE)
    write(paste("SampleSize = ", n.ind), file = filename.connection, append = TRUE)
    write(paste("SampleData = {"), file = filename.connection, append = TRUE)
    pop.data$INDIVIDUALS[seq(from = 2, to = n.ind * 2, by = 2)] <- ""
    # test <- data.frame(input.split[[i]])
    # close(filename.connection) # close the connection
    pop.data <- dplyr::select(.data = pop.data, -POP_ID)
    ncol.data <- ncol(pop.data)
    pop.data <- as.matrix(pop.data)
    write(x = t(pop.data), ncolumns = ncol.data, sep = "\t", append = TRUE, file = filename.connection)
    write("}", file = filename.connection, append = TRUE)
  }
  
  write(paste("[[Structure]]"), file = filename.connection, append = TRUE)
  write(paste("StructureName = ", "\"", "One cluster", "\""), file = filename.connection, append = TRUE)
  write(paste("NbGroups = 1"), file = filename.connection, append = TRUE)
  write(paste("Group = {"), file = filename.connection, append = TRUE)
  for (i in 1:length(input.split)) {
    pop.data <- input.split[[i]]
    pop.name <- unique(pop.data$POP_ID)
    write(paste("\"", pop.name, "\"", sep = ""), file = filename.connection, append = TRUE)
  }
  write(paste("}"), file = filename.connection, append = TRUE)
} # end write_arlequin
