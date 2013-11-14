/* xxx_sig.sig */

#define KALLE (1000)
#define EXPR (10 + KALLE)

struct dynamic4
{
  U32 testValue3;
  U8 array3Size;
  S32 array3[1];
};
/* !-ARRAY_SIZE(array3, array3Size)-! */

struct dynamic3
{
  U16 testValue2;
  U32 array2Size;
  struct dynamic4 array2[1];
};
/* !-ARRAY_SIZE(array2, array2Size)-! */

struct dynamic2
{
  U8 testValue3;
  U8 array3Size;
  S32 array3[1];
};
/* !-ARRAY_SIZE(signal2.array1.array2.array3, array3Size)-! */

struct dynamic1
{
  U32 testValue2;
  U16 array2Size;
  struct dynamic2 array2[1];
};
/* !-ARRAY_SIZE(signal2.array1.array2, array2Size)-! */


#define SIGNAL2 (EXPR+ 1) /* !-SIGNO(struct signal2)-! */
struct signal2
{
  SIGSELECT sigNo;
  U32 testValue1;
  U32 array1Size;
  struct dynamic1 array1[4];
};
/* !-ARRAY_SIZE(signal2.array1, array1Size)-! */

/* End of file */
