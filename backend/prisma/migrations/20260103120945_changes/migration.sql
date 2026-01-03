-- CreateTable
CREATE TABLE "CareTask" (
    "id" TEXT NOT NULL,
    "plantId" TEXT NOT NULL,
    "taskName" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "frequencyDays" INTEGER NOT NULL,
    "xpReward" INTEGER NOT NULL,
    "instruction" TEXT,
    "lastCompletedAt" TIMESTAMP(3),
    "nextDueAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CareTask_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "CareTask_plantId_idx" ON "CareTask"("plantId");

-- AddForeignKey
ALTER TABLE "CareTask" ADD CONSTRAINT "CareTask_plantId_fkey" FOREIGN KEY ("plantId") REFERENCES "Plant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
