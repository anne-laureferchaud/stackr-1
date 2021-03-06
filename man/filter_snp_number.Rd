% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/filter_snp_number.R
\name{filter_snp_number}
\alias{filter_snp_number}
\title{SNP number filter}
\usage{
filter_snp_number(data, max.snp.number, pop.threshold, percent, filename)
}
\arguments{
\item{data}{A data frame object or file (using ".tsv")
of class sumstats or a tidy VCF summarised.}

\item{max.snp.number}{Number}

\item{pop.threshold}{Fixed number of pop required to keep the locus.}

\item{percent}{Is the threshold a percentage ? TRUE or FALSE.}

\item{filename}{Name of the file written to the working directory (optional).}
}
\description{
Filter the dataset (sumstats or tidy vcf) to remove loci with more than x SNP.
}

