typedef unsigned long SIGSELECT;

struct xerxes
{
  int mark;
  char land;
};

#define TEST_SIG (7878) /*!-SIGNO(struct testS)-!*/

struct testS
{
  SIGSELECT sigNo;
  int halvar;
  char sentinel;
};

#define HAIR_SIG (7879) /*!-SIGNO(struct hairS)-!*/

struct hairS
{
  SIGSELECT sigNo;
};

#define POI_SIG (7880) /*!-SIGNO(struct poiS)-!*/

struct poiS
{
  SIGSELECT sigNo;
  int *poison;
};

