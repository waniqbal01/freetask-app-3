-- CreateIndex
CREATE INDEX "Job_clientId_idx" ON "Job"("clientId");

-- CreateIndex
CREATE INDEX "Job_freelancerId_idx" ON "Job"("freelancerId");

-- CreateIndex
CREATE INDEX "Job_status_idx" ON "Job"("status");

-- CreateIndex
CREATE INDEX "Job_autoCompleteAt_idx" ON "Job"("autoCompleteAt");

-- CreateIndex
CREATE INDEX "Job_status_autoCompleteAt_idx" ON "Job"("status", "autoCompleteAt");
