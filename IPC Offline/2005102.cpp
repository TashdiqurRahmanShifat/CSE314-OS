#include <iostream>
#include <thread>
#include <vector>
#include <semaphore.h>
#include <mutex>
#include <random>
#include <functional>//for bind
#include <unistd.h>//for sleep

using namespace std;

//Semaphore for Gallery 1 and Corridor
sem_t gallery1_semaphore;
sem_t corridor_semaphore;

//Semaphore through each step
mutex step_mutex[3];


int readerCount=0,writerCount=0;
mutex readerCountLock;
mutex writerCountLock;
mutex photoBoothLock;
mutex readerLock;

pthread_mutex_t output_lock;


int get_random_number() {
    // Creates a random device for non-deterministic random number generation
    std::random_device rd;
    // Initializes a random number generator using the random device
    std::mt19937 generator(rd());

    // Lambda value for the Poisson distribution (you can still use lambda = 10000.234)
    // double lambda = 10000.234;
    double lambda=2;

    // Defines a Poisson distribution with the given lambda
    std::poisson_distribution<int>poissonDist(lambda);

    // Generates a Poisson-distributed number
    int random_num=poissonDist(generator);
    return random_num;
}


timespec start_time;
/**
 * Initialize the start time for the simulation.
 */
void initialize_start_time() {
    clock_gettime(CLOCK_MONOTONIC, &start_time);
}


long long get_time() {
    timespec current_time;
    clock_gettime(CLOCK_MONOTONIC, &current_time);
    long long elapsed_seconds = current_time.tv_sec - start_time.tv_sec;
    return elapsed_seconds;
}


class Visitor {
public:
    int id;
    Visitor(int id) : id(id){}
};


//Print the visitor's location with a timestamp
void write_output(const Visitor& visitor, const string& location) {
    pthread_mutex_lock(&output_lock);
    cout<<"Visitor "<<visitor.id<<" "<<location<<" at time stamp "<<to_string(get_time())<<endl;
    pthread_mutex_unlock(&output_lock);
}

void standard_ticket_holder(Visitor visitor,int z)
{
    readerLock.lock();//Check if writer locks reader or not
    readerCountLock.lock();
    readerCount++;
    if(readerCount==1)
        photoBoothLock.lock();
    readerCountLock.unlock();
    readerLock.unlock();

    write_output(visitor,"is inside the photo booth");
    sleep(z);

    readerCountLock.lock();
    readerCount--;
    if(readerCount==0)
        photoBoothLock.unlock();
    readerCountLock.unlock();
}

void premium_ticket_holder(Visitor visitor,int z)
{
    writerCountLock.lock();//Applying lock to change writer count
    writerCount++;
    if(writerCount==1)
        readerLock.lock();//Reader should not get access
    writerCountLock.unlock();

    photoBoothLock.lock();
    write_output(visitor,"is inside the photo booth");
    sleep(z);
    photoBoothLock.unlock();
    
    writerCountLock.lock();
    writerCount--;
    if(writerCount==0)
        readerLock.unlock();
    writerCountLock.unlock();
}

void start(Visitor visitor,int w,int x,int y,int z) 
{
    sleep(get_random_number());
    //get_random_number();
    // Entry point A
    write_output(visitor, "has arrived at A");
    //random_delay(get_random_number());
    //this_thread::sleep_for(chrono::milliseconds(w));
    sleep(w);

    //Hallway AB
    write_output(visitor, "has arrived at B");
    sleep(1);

    step_mutex[0].lock();
    write_output(visitor, "is at step 1");
    //this_thread::sleep_for(chrono::milliseconds(1));
    sleep(1);
    step_mutex[1].lock();
    
    write_output(visitor, "is at step 2");
    //this_thread::sleep_for(chrono::milliseconds(1));
    step_mutex[0].unlock();
    sleep(1);

    step_mutex[2].lock();

    write_output(visitor, "is at step 3");
    //this_thread::sleep_for(chrono::milliseconds(1));
    
    step_mutex[1].unlock();
    sleep(1);

    
    sem_wait(&gallery1_semaphore);

    write_output(visitor, "is at C (entered Gallery 1)");
    //this_thread::sleep_for(chrono::milliseconds(x)); 
    step_mutex[2].unlock();
    sleep(x);

    
    sem_wait(&corridor_semaphore);
    write_output(visitor, "is at D (exiting Gallery 1)");
    //this_thread::sleep_for(chrono::milliseconds(320));
    sleep(1);
    sem_post(&gallery1_semaphore);
    sem_post(&corridor_semaphore);

    write_output(visitor,"is at E (entered Gallery 2)");
    //this_thread::sleep_for(chrono::milliseconds(y));
    sleep(y);

    write_output(visitor,"is about to enter the photo booth");
    //usleep(1);


    if(visitor.id>=1001 && visitor.id<=1100)
        standard_ticket_holder(visitor,z);//Reader
    else if(visitor.id>=2001 && visitor.id<=2100)
        premium_ticket_holder(visitor,z);//Writer
}

int main(int argc,char *argv[]) {

    if(argc!=7)
    {
        cout<<"Usage:N M \n w x y z";
        exit(1);
    }

    int N,M,w,x,y,z;
    N=atoi(argv[1]);
    M=atoi(argv[2]);
    w=atoi(argv[3]);
    x=atoi(argv[4]);
    y=atoi(argv[5]);
    z=atoi(argv[6]);


    vector<thread>visitorArray;

    initialize_start_time();
    //initialization
    sem_init(&gallery1_semaphore,0,5); 
    sem_init(&corridor_semaphore,0,3);

    // Initialize mutex lock for thread-safe output
    pthread_mutex_init(&output_lock,nullptr);





    //Standard
    for(int i=0;i<N;i++){
        int visitor_id=1001+i;
        visitorArray.push_back(thread(std::bind(start,Visitor(visitor_id),w,x,y,z)));
    }

    //Premium
    for(int i=0;i<M;i++){
        int visitor_id=2001+i;
        visitorArray.push_back(thread(std::bind(start,Visitor(visitor_id),w,x,y,z)));
    }

    for(auto &visitor:visitorArray){
        visitor.join();
    }

    sem_destroy(&gallery1_semaphore);
    sem_destroy(&corridor_semaphore);
    return 0;
}
