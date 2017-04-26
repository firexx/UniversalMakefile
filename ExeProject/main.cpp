/*
 * =====================================================================================
 *
 *       Filename:  main.cpp
 *
 *    Description:  
 *
 *        Version:  1.0
 *        Created:  21.04.2017 12:21:19
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  Andrej Kostrov (ak), andrej.kostrov@dermalog.com
 *        Company:  DERMALOG Identification Systems GmbH
 *
 * =====================================================================================
 */

#include <ExeProject.h>
#include <LibProject.h>
#include <DllProject.h>
int main(){
    libprint("libprint");
    dllprint("dllprint");
    return 0;
}
