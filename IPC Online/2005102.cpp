#include <fstream>
#include <iostream>
#include <random>
#include <vector>
#include <iomanip>
#include <chrono>

#include<semaphore.h>
#include <pthread.h>
#include <unistd.h>

using namespace std;

sem_t out_lock;
int N,L;
int tc=0,wc=0;
int itr=0;


void initialize_system() {
    sem_init(&out_lock,0,1);
}

void destroy() {
    sem_destroy(&out_lock);
}


void tc_handle(){

        if(wc==L)
        {   
            itr++;
            cout<<"$  [iteration "<<itr<<"]"<<endl;
            wc=0;
            tc++;
            if(tc==N)exit(0);
        }
}

void*  A_activities(void * args){
    for(int i=0;;i++){
        sem_wait(&out_lock);
        {
            cout<<"A";
            wc++;
        }

        tc_handle();
        sem_post(&out_lock);
 
    }
    return NULL;
}


void*  B_activities(void * args){
    for(int i=0;;i++){
        sem_wait(&out_lock);
        {
            cout<<"B";
            wc++;
        }

        tc_handle();
        sem_post(&out_lock);
        
    }
    return NULL;
}


void*  C_activities(void * args){
    for(int i=0;;i++){
        sem_wait(&out_lock);
        {
            cout<<"C";wc++;
        }

        tc_handle();
        sem_post(&out_lock);
        
    }
    return NULL;
}



int main(int argc, char* argv[]){
    if (argc != 3) {
        cout << "Usage: ./a.out N" << endl;
        return 0;
    }
    N=stoi(argv[1]);
    L=stoi(argv[2]);
    initialize_system();

    pthread_t p_t;
    pthread_t q_t;
    pthread_t r_t;
    
    pthread_create(&p_t, NULL, A_activities, NULL);
    pthread_create(&q_t, NULL, B_activities, NULL);
    pthread_create(&r_t, NULL, C_activities, NULL);

    pthread_join(p_t,NULL);
    pthread_join(q_t,NULL);
    pthread_join(r_t,NULL);
    
    destroy();

    return 0;

}