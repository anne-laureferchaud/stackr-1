% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/write_plink.R
\name{write_plink}
\alias{write_plink}
\title{Write a plink tped/tfam file from a tidy data frame}
\usage{
write_plink(data, filename = NULL)
}
\arguments{
\item{data}{A tidy data frame object in the global environment or
a tidy data frame in wide or long format in the working directory.
\emph{How to get a tidy data frame ?}
Look into \pkg{stackr} \code{\link{tidy_genomic_data}}.}

\item{filename}{(optional) The file name prefix for tped/tfam files 
written to the working directory. With default: \code{filename = NULL}, 
the date and time is appended to \code{stackr_plink_}.}
}
\description{
Write a plink file from a tidy data frame.
Used internally in \href{https://github.com/thierrygosselin/stackr}{stackr} 
and \href{https://github.com/thierrygosselin/assigner}{assigner}
and might be of interest for users.
}
\author{
Thierry Gosselin \email{thierrygosselin@icloud.com}
}
\references{
Purcell S, Neale B, Todd-Brown K, Thomas L, Ferreira MAR, 
Bender D, et al. 
PLINK: a tool set for whole-genome association and population-based linkage 
analyses. 
American Journal of Human Genetics. 2007: 81: 559–575. doi:10.1086/519795
}

