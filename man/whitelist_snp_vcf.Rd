% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/whitelist_blacklist.R
\name{whitelist_snp_vcf}
\alias{whitelist_snp_vcf}
\title{Whitelist loci for VCF tools}
\usage{
whitelist_snp_vcf(data, filename)
}
\arguments{
\item{data}{A tidy vcf or sumstats prep file (using ".tsv") or object in
your Environment.}

\item{filename}{The name of the file written in the directory.}
}
\description{
This function creates a whitelist of loci for VCF tools.
With 2 columns (CHROM and POS).
}
\author{
Thierry Gosselin \email{thierrygosselin@icloud.com}
}
\seealso{
\link{tidy_genomic_data} and  \link{summary_stats_vcf_tidy}
}

