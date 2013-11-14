/*  ogre_sig_dyn.h  */

/* 
 * This file specifies the relations between a dynamic array
 * and the member containing the array length.
 */

/*              array                                size          */
/* --------------------------------------------------------------- */
/* !-ARRAY_SIZE(ogre_dyn_req.dyn1_array.dyn2_array.dyn3_array,  size2     )-! */
/* !-ARRAY_SIZE(ogre_dyn_rsp.dyn1_array.dyn2_array.dyn3_array,  size2     )-! */
/* !-ARRAY_SIZE(ogre_dyn_req.dyn1_array.dyn2_array,  size1     )-! */
/* !-ARRAY_SIZE(ogre_dyn_rsp.dyn1_array.dyn2_array,  size1     )-! */

/* !-ARRAY_SIZE(ogre_dyn_req.fix1_array.dyn2_array.dyn3_array,  size2     )-! */
/* !-ARRAY_SIZE(ogre_dyn_rsp.fix1_array.dyn2_array.dyn3_array,  size2     )-! */
/* !-ARRAY_SIZE(ogre_dyn_req.fix1_array.dyn2_array,  size1     )-! */
/* !-ARRAY_SIZE(ogre_dyn_rsp.fix1_array.dyn2_array,  size1     )-! */

/* !-ARRAY_SIZE(ogre_dyn_req.dyn1_array,             size      )-! */
/* !-ARRAY_SIZE(ogre_dyn_rsp.dyn1_array,             size      )-! */

/* !-ARRAY_SIZE(ogre_big_req.data,                   data_size )-! */
/* !-ARRAY_SIZE(ogre_big_rsp.data,                   data_size )-! */

