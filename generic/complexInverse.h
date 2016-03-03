#ifndef COMPLEX_INVERSE_H
#define COMPLEX_INVERSE_H

void getComplexInverse (int, double complex*);
void getComplexInverseHessenberg (const int, double complex* __restrict__, int * __restrict__,
									int * __restrict__, double complex * __restrict__, const int);

#endif