\name{zuexacttest}
\alias{zuexacttest}
\alias{ct_info}
\alias{ct_sum}
\alias{ct_dot}
\alias{ct_diff}
\alias{ct_mean}
\alias{ct_round_acc}
\alias{ct_sum_parts}
\title{Fixture Consumer of the zuexact C Interface}
\description{
Each function calls the registered 'zuexact' C table from C:
\code{ct_info()} returns the table's struct size and accumulator size;
\code{ct_sum()}, \code{ct_dot()} and \code{ct_mean()} sum, take dot products
and means; \code{ct_diff()} subtracts two sums by negating and merging;
\code{ct_round_acc()} rounds the bytes of an \code{xsum_acc};
\code{ct_sum_parts()} sums interleaved slices in separate accumulators and
merges them.
}
\usage{
ct_info()
ct_sum(x)
ct_dot(x, y)
ct_diff(x, y)
ct_mean(x)
ct_round_acc(acc)
ct_sum_parts(x, parts)
}
\arguments{
\item{x, y}{Numeric vectors.}
\item{acc}{An accumulator from \code{zuexact::xsum_acc()}.}
\item{parts}{Number of partial accumulators, 1 to 64.}
}
\value{A double vector.}
\examples{
ct_sum(c(1e20, 1, -1e20))
}
