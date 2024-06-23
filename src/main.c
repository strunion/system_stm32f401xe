#include <stm32f401xe.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "xprintf.h"
#include "cmsis_os.h"

#define LED_GPIO        GPIOC
#define LED_PIN         13

#define USART_GPIO      GPIOA

osThreadId_t defaultTaskHandle;

void StartDefaultTask(void *argument);

const osThreadAttr_t defaultTask_attributes = {
  .name = "default",
  .priority = (osPriority_t) osPriorityNormal,
  .stack_size = 256 * 4
};

void StartDefaultTask(void *argument){
    for(;;){
        LED_GPIO->BSRR = (1 << LED_PIN);
        osDelay(1000);
        LED_GPIO->BSRR = (1 << (LED_PIN + 16));
        osDelay(1000);
    }
}

void createTasks(void){
    defaultTaskHandle = osThreadNew(StartDefaultTask, NULL, &defaultTask_attributes);
}

int main(void) {
    RCC->AHB1ENR  |= RCC_AHB1ENR_GPIOCEN;
    RCC->APB2ENR  |= RCC_APB2ENR_USART1EN;

    USART_GPIO->MODER |= GPIO_MODER_MODE10_1 | GPIO_MODER_MODE9_1;
    USART_GPIO->AFR[1] |= (7 << GPIO_AFRH_AFSEL9_Pos) | (7 << GPIO_AFRH_AFSEL10_Pos);
    USART1->BRR = F_CPU / 9600;
    USART1->CR1 = USART_CR1_TE | USART_CR1_RE | USART_CR1_UE;

    LED_GPIO->MODER |= (0b01 << (LED_PIN << 1));

    osKernelInitialize();
    createTasks();
    osKernelStart();

    while(1) {
    }
}
