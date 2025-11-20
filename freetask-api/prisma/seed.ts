import { PrismaClient, UserRole, JobStatus, Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function createUser(params: {
  email: string;
  name: string;
  role: UserRole;
  password: string;
  bio?: string;
  skills?: string[];
  rate?: number;
}) {
  const hashed = await bcrypt.hash(params.password, 10);
  return prisma.user.upsert({
    where: { email: params.email },
    update: {
      name: params.name,
      role: params.role,
      bio: params.bio,
      skills: params.skills,
      rate: params.rate ? new Prisma.Decimal(params.rate) : undefined,
      enabled: true,
    },
    create: {
      email: params.email,
      name: params.name,
      role: params.role,
      password: hashed,
      bio: params.bio,
      skills: params.skills,
      rate: params.rate ? new Prisma.Decimal(params.rate) : undefined,
    },
  });
}

async function resetTables() {
  await prisma.jobHistory.deleteMany();
  await prisma.chatMessage.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.review.deleteMany();
  await prisma.job.deleteMany();
  await prisma.service.deleteMany();
  await prisma.user.deleteMany();
}

async function seedServices(freelancerId: number) {
  const servicesData = [
    {
      title: 'Logo Identity Essentials',
      description: 'Reka bentuk logo moden dengan 2 pusingan revisi.',
      price: new Prisma.Decimal(220),
      category: 'Design',
      deliveryDays: 3,
    },
    {
      title: 'Landing Page Next.js',
      description: 'Laman pendaratan pantas lengkap dengan analitik asas.',
      price: new Prisma.Decimal(420),
      category: 'Development',
      deliveryDays: 5,
    },
    {
      title: 'Pakej Sosial Media 10 Pos',
      description: 'Kandungan kapsyen & visual ringan untuk kempen mingguan.',
      price: new Prisma.Decimal(180),
      category: 'Marketing',
      deliveryDays: 4,
    },
  ];

  const services: Array<{ id: number; title: string; freelancerId: number; price: number }> = [];
  for (const data of servicesData) {
    // eslint-disable-next-line no-await-in-loop
    const service = await prisma.service.upsert({
      where: { title: data.title },
      update: { ...data, freelancerId },
      create: { ...data, freelancerId },
    });
    services.push({
      id: service.id,
      title: service.title,
      freelancerId: service.freelancerId,
      price: Number(service.price),
    });
  }
  return services;
}

async function seedJobs(params: {
  services: Array<{ id: number; title: string; freelancerId: number; price: number }>;
  clientId: number;
}) {
  const [logo, landing, social] = params.services;

  const jobs = await Promise.all([
    prisma.job.create({
      data: {
        title: 'Logo untuk aplikasi kewangan',
        description: 'Logo minimal dengan warna hijau neon.',
        amount: new Prisma.Decimal(logo.price),
        status: JobStatus.PENDING,
        serviceId: logo.id,
        clientId: params.clientId,
        freelancerId: logo.freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Sediakan landing page MVP',
        description: 'Keutamaan pada borang lead dan kelajuan.',
        amount: new Prisma.Decimal(landing.price),
        status: JobStatus.ACCEPTED,
        serviceId: landing.id,
        clientId: params.clientId,
        freelancerId: landing.freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Kempen media sosial 10 hari',
        description: '10 kapsyen dan visual ringkas untuk promosi.',
        amount: new Prisma.Decimal(social.price),
        status: JobStatus.IN_PROGRESS,
        serviceId: social.id,
        clientId: params.clientId,
        freelancerId: social.freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Logo pasukan e-sukan',
        description: 'Gaya maskot berani dengan warna ungu.',
        amount: new Prisma.Decimal(260),
        status: JobStatus.COMPLETED,
        serviceId: logo.id,
        clientId: params.clientId,
        freelancerId: logo.freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Semakan semula visual kempen',
        description: 'Dispute kerana visual tidak ikut moodboard.',
        amount: new Prisma.Decimal(social.price),
        status: JobStatus.DISPUTED,
        disputeReason: 'Warna dan susun atur tidak mengikut contoh rujukan.',
        serviceId: social.id,
        clientId: params.clientId,
        freelancerId: social.freelancerId,
      },
    }),
  ]);

  await prisma.jobHistory.createMany({
    data: [
      { jobId: jobs[0].id, actorId: params.clientId, action: 'JOB_CREATED' },
      { jobId: jobs[1].id, actorId: params.clientId, action: 'JOB_CREATED' },
      { jobId: jobs[1].id, actorId: params.clientId, action: 'JOB_ACCEPTED' },
      { jobId: jobs[2].id, actorId: params.clientId, action: 'JOB_CREATED' },
      { jobId: jobs[2].id, actorId: jobs[2].freelancerId, action: 'JOB_ACCEPTED' },
      { jobId: jobs[2].id, actorId: jobs[2].freelancerId, action: 'JOB_STARTED' },
      { jobId: jobs[3].id, actorId: params.clientId, action: 'JOB_CREATED' },
      { jobId: jobs[3].id, actorId: jobs[3].freelancerId, action: 'JOB_ACCEPTED' },
      { jobId: jobs[3].id, actorId: jobs[3].freelancerId, action: 'JOB_STARTED' },
      { jobId: jobs[3].id, actorId: jobs[3].freelancerId, action: 'JOB_COMPLETED' },
      { jobId: jobs[4].id, actorId: params.clientId, action: 'JOB_CREATED' },
      {
        jobId: jobs[4].id,
        actorId: params.clientId,
        action: 'JOB_DISPUTED',
        message: 'Visual tidak selaras.',
      },
    ],
  });

  await prisma.chatMessage.createMany({
    data: [
      {
        content: 'Hai, saya akan hantar konsep logo pertama petang ini.',
        jobId: jobs[0].id,
        senderId: jobs[0].freelancerId,
      },
      {
        content: 'Boleh guna tona neon hijau untuk versi pertama.',
        jobId: jobs[0].id,
        senderId: params.clientId,
      },
      {
        content: 'Wireframe siap, saya mulakan pembangunan hari ini.',
        jobId: jobs[1].id,
        senderId: jobs[1].freelancerId,
      },
    ],
  });

  await prisma.notification.createMany({
    data: [
      {
        userId: jobs[0].freelancerId,
        type: 'JOB_CREATED',
        title: 'Job baharu ditempah',
        body: 'Client menempah Logo Identity Essentials.',
        metadata: { jobId: jobs[0].id, serviceId: logo.id },
      },
      {
        userId: params.clientId,
        type: 'JOB_STATUS_UPDATED',
        title: 'Job diterima',
        body: 'Freelancer bersedia untuk job Landing Page Next.js.',
        metadata: { jobId: jobs[1].id, status: JobStatus.ACCEPTED },
      },
      {
        userId: params.clientId,
        type: 'JOB_STATUS_UPDATED',
        title: 'Status job berubah',
        body: 'Kempen media sosial kini In Progress.',
        metadata: { jobId: jobs[2].id, status: JobStatus.IN_PROGRESS },
      },
    ],
  });

  return jobs;
}

export async function runSeed() {
  console.log('🌱 Resetting and seeding demo data...');
  await resetTables();

  const admin = await createUser({
    email: 'admin@demo.com',
    name: 'Demo Admin',
    role: UserRole.ADMIN,
    password: 'Admin123!',
  });

  const client = await createUser({
    email: 'client@demo.com',
    name: 'Demo Client',
    role: UserRole.CLIENT,
    password: 'Client123!',
  });

  const freelancer = await createUser({
    email: 'freelancer@demo.com',
    name: 'Demo Freelancer',
    role: UserRole.FREELANCER,
    password: 'Freelancer123!',
    bio: 'Pereka dan pembangun bebas untuk MVP dan bahan pemasaran.',
    skills: ['Design', 'Next.js', 'Copywriting'],
    rate: 120,
  });

  const services = await seedServices(freelancer.id);
  const jobs = await seedJobs({ services, clientId: client.id });

  console.log('✅ Demo users:', {
    admin: admin.email,
    client: client.email,
    freelancer: freelancer.email,
  });
  console.log('✅ Services:', services.map((service) => service.title).join(', '));
  console.log('✅ Jobs:', jobs.map((job) => `#${job.id} ${job.status}`).join(', '));
  console.log('✨ Seeding complete.');
}

if (require.main === module) {
  runSeed()
    .catch((error) => {
      console.error('Seed failed:', error);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
