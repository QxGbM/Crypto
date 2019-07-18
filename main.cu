
#include <pspl.cuh>

__global__ void getrf_kernel(double *matrix, const int nx, const int ny, const int ld, int *pivot)
{
  __shared__ double shm[6144];
  blockDenseGetrf <double, double2, 2, _DEFAULT_BLOCK_M, _DEFAULT_BLOCK_K> (matrix, nx, ny, ld, shm);
  //DenseGetrf <double, double2, 2> (matrix, nx, ny, ld);
}

template <class T, class vecT, int vec_size> __host__ int test0 (const bool ref, const int blocks, const int threads, const int shadow_rank = _DEFAULT_SHADOW_RANK)
{
  cudaSetDevice(0);
  cudaDeviceReset();

  rndInitialize <T> (200);

  dev_hierarchical<T> * a = dev_hierarchical<T>::readFromFile("bin/test", shadow_rank);

  cudaError_t error = hierarchical_GETRF <T, vecT, vec_size, 12288> (a, blocks, threads);

  if (ref && error == cudaSuccess)
  {
    dev_dense <T> * b = a->convertToDense(), * c = dev_dense <T>::readFromFile("bin/ref", 0);

    timer my_timer = timer();
    my_timer.newEvent("ref", start);
    getrf_kernel <<<1, threads, 0, 0 >>> (c -> getElements(), c -> getNx(), c -> getNy(), c -> getLd(), nullptr);
    my_timer.newEvent("ref", end);

    my_timer.dumpAllEvents_Sync();

    printf("Rel. L2 Error: %e\n\n", c -> L2Error(b)); 
    delete b; b = nullptr;
    delete c; c = nullptr;
  }

  delete a;

  return 0;
}



int main(int argc, char * argv[])
{
  int blocks = 80, threads = 512, rank = _DEFAULT_SHADOW_RANK;
  bool ref = true;

  for (int i = 1; i < argc; i++)
  {
    if (strncmp(argv[i], "-rank=", 6) == 0)
    { sscanf(argv[i], "-rank=%d", &rank); }
    else if (strncmp(argv[i], "-blocks=", 8) == 0)
    { sscanf(argv[i], "-blocks=%d", &blocks); }
    else if (strncmp(argv[i], "-threads=", 9) == 0)
    { sscanf(argv[i], "-threads=%d", &threads); }
    else if (strcmp(argv[i], "-noref") == 0)
    { ref = false; }
    else if (strcmp(argv[i], "-ref") == 0)
    { ref = true; }
    else
    { printf("Unrecognized Arg: %s.\n", argv[i]); }
  }

  test0 <double, double2, 2> (ref, blocks, threads, rank);

  return 0;
}