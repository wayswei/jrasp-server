<template>
  <div>
    <el-card class="container-card" shadow="always">
      <!-- 条件搜索框 -->
      <el-form :size="this.$store.getters.size" :inline="true" :model="params" class="demo-form-inline">
        <el-form-item label="实例名称">
          <el-input v-model.trim="params.hostName" clearable placeholder="实例名称" @clear="search" />
        </el-form-item>
        <el-form-item label="实例IP">
          <el-input v-model.trim="params.ip" clearable placeholder="IP" @clear="search" />
        </el-form-item>
        <el-form-item label="接入方式">
          <el-select v-model.trim="params.agentMode" clearable placeholder="接入模式" @change="search" @clear="search">
            <el-option label="动态" value="dynamic" />
            <el-option label="静态" value="static" />
            <el-option label="禁用" value="disable" />
            <el-option label="全部" value="" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button :loading="loading" icon="el-icon-search" type="primary" @click="search">查询</el-button>
        </el-form-item>
        <el-form-item>
          <el-button
            :disabled="multipleSelection.length === 0"
            :loading="loading"
            icon="el-icon-delete"
            type="danger"
            @click="batchDelete"
          >批量删除
          </el-button>
        </el-form-item>
        <el-form-item>
          <el-button
            :disabled="multipleSelection.length === 0"
            :loading="loading"
            icon="el-icon-delete"
            type="warning"
            @click="batchUpdate"
          >批量更新
          </el-button>
        </el-form-item>
      </el-form>
      <!-- 主机列表 -->
      <el-table
        v-loading="loading"
        :data="tableData"
        border
        stripe
        style="width: 100%"
        :size="this.$store.getters.size"
        @selection-change="handleSelectionChange"
      >
        <el-table-column type="selection" width="55" align="center" />
        <el-table-column label="序号" type="index" width="50" align="center">
          <template slot-scope="scope">
            {{ (params.pageNum - 1) * params.pageSize + scope.$index + 1 }}
          </template>
        </el-table-column>
        <el-table-column show-overflow-tooltip sortable prop="hostName" label="实例名称" align="center" />
        <el-table-column show-overflow-tooltip sortable prop="ip" label="实例IP" width="150" align="center" />
        <el-table-column show-overflow-tooltip sortable prop="agentMode" label="接入方式" width="120" align="center">
          <template slot-scope="scope">
            <el-tag size="medium" :type="getAgentMode(scope.row.agentMode).color" disable-transitions>
              {{ getAgentMode(scope.row.agentMode).value }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column show-overflow-tooltip sortable label="在线状态" width="120" align="center">
          <template slot-scope="scope">
            <el-tag size="medium" :type="isOnline(scope.row.heartbeatTime) === true ? 'success' : 'danger'" disable-transitions>
              {{ isOnline(scope.row.heartbeatTime) ? '在线' : '离线' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column show-overflow-tooltip prop="version" label="RASP版本" align="center" width="100" />
        <el-table-column show-overflow-tooltip sortable prop="configId" label="防护策略" align="center">
          <template slot-scope="scope">
            {{ getConfigNameById(scope.row.configId) }}
          </template>
        </el-table-column>
        <el-table-column show-overflow-tooltip sortable prop="heartbeatTime" :formatter="dateFormat" label="心跳时间" width="180" align="center" />
        <el-table-column show-overflow-tooltip sortable prop="CreatedAt" :formatter="dateFormat" label="注册时间" width="180" align="center" />
        <el-table-column fixed="right" label="操作" width="180" align="center">
          <template slot-scope="scope">
            <el-button type="text" size="medium" @click="handleDelete(scope.row)">删除</el-button>
            <el-button type="text" size="medium" @click="showHostAndProcessDetail(scope.row)">详情</el-button>
            <el-button type="text" size="medium" @click="updateConfig(scope.row)">更新策略</el-button>
          </template>
        </el-table-column>
      </el-table>
      <!--分页配置-->
      <el-pagination
        :current-page="params.pageNum"
        :page-size="params.pageSize"
        :total="total"
        :page-sizes="[10, 20, 50, 100]"
        layout="total, prev, pager, next, sizes"
        background
        style="margin-top: 10px;float:right;margin-bottom: 10px;"
        @size-change="handleSizeChange"
        @current-change="handleCurrentChange"
      />

      <!-- 新建进程详情对话框 -->
      <el-dialog title="进程详情" :visible.sync="showProcessInfoVisible">
        <!-- 进程列表 -->
        <el-table
          v-loading="processLoading"
          :data="processTableData"
          border
          stripe
          style="width: 100%"
        >
          <el-table-column show-overflow-tooltip sortable prop="pid" label="PID" align="center" />
          <el-table-column show-overflow-tooltip sortable prop="startTime" label="启动时间" align="center" />
          <el-table-column show-overflow-tooltip sortable prop="status" label="保护状态" align="center">
            <template slot-scope="scope">
              <el-tag size="small" :type="getAgentStatusColor(scope.row.status)" disable-transitions>
                {{ getAgentStatusText(scope.row.status) }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column show-overflow-tooltip sortable prop="cmdlineInfo" label="命令行信息" align="center" />
        </el-table>
        <el-pagination
          :current-page="processParams.pageNum"
          :page-size="processParams.pageSize"
          :total="processTotal"
          :page-sizes="[1, 2, 5, 10]"
          layout="total, prev, pager, next, sizes"
          background
          style="margin-top: 10px;float:left;margin-bottom: 10px;"
          @size-change="processHandleSizeChange"
          @current-change="processHandleCurrentChange"
        />
        <div slot="footer" class="dialog-footer">
          <el-button size="mini" @click="closeProcessInfoVisible()">关 闭</el-button>
        </div>
      </el-dialog>

      <!-- 配置下发对话框 -->
      <el-dialog title="配置下发" :visible.sync="updateConfigVisible" width="30%">
        <el-form ref="configDialogForm" label-width="80px" size="small" :model="configFormData">
          <el-form-item label="主机名称" prop="hostName">
            <el-input v-model="configFormData.hostName" readonly />
          </el-form-item>
          <el-form-item label="配置名称" prop="configId">
            <el-select v-model="configFormData.configId" clearable placeholder="前选择配置" width="100%">
              <el-option
                v-for="item in allConfigs"
                :key="item.ID"
                :label="item.name"
                :value="item.ID"
              />
            </el-select>
          </el-form-item>
        </el-form>
        <div slot="footer" class="dialog-footer">
          <el-button size="mini" @click="closeConfigForm()">取 消</el-button>
          <el-button size="mini" :loading="submitConfigPushLoading" type="primary" @click="submitConfigPushForm()">确 定
          </el-button>
        </div>
      </el-dialog>

    </el-card>
  </div>
</template>

<script>

import { batchDeleteHost, getHosts, getProcesss, pushConfig, updateConfig } from '@/api/host/host'
import { getConfigs } from '@/api/config/config'
import moment from 'moment/moment'

export default {
  name: 'Host',
  data() {
    return {
      // 查询参数
      params: {
        hostName: '',
        ip: '',
        pageNum: 1,
        pageSize: 10
      },

      allConfigs: [],
      configFormData: {
        hostName: '',
        hostId: '',
        configId: ''
      },

      // 表格数据
      tableData: [],
      total: 0,
      loading: false,
      // 表格多选
      multipleSelection: [],

      // 进程详情弹窗
      // 查询参数
      processParams: {
        hostName: '',
        status: '',
        pageNum: 1,
        pageSize: 2
      },
      currentHostName: '',
      showProcessInfoVisible: false,
      processTableData: [],
      processTotal: 0,
      processLoading: false,

      // 配置更新
      updateConfigVisible: false,
      submitConfigPushLoading: false
    }
  },
  created() {
    this.getTableData()
    this.getAllConfig()
  },
  methods: {
    // 查询
    search() {
      this.params.pageNum = 1
      this.getTableData()
    },

    // 获取表格数据
    async getTableData() {
      this.loading = true
      try {
        const { data } = await getHosts(this.params)
        this.tableData = data.data
        this.total = data.total
      } finally {
        this.loading = false
      }
    },

    async getProcessTable() {
      this.processLoading = true
      try {
        const { data } = await getProcesss(this.processParams)
        this.processTableData = data.data
        this.processTotal = data.total
      } finally {
        this.processLoading = false
      }
    },

    handleDelete(record) {
      this.$confirm('此操作将永久删除, 是否继续?', '提示', {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }).then(async res => {
        this.loading = true
        let msg = ''
        try {
          const { message } = await batchDeleteHost({ ids: [record.ID] })
          msg = message
        } finally {
          this.loading = false
        }

        await this.getTableData()
        this.$message({
          showClose: true,
          message: msg,
          type: 'success'
        })
      }).catch(() => {
        this.$message({
          showClose: true,
          type: 'info',
          message: '已取消删除'
        })
      })
    },

    updateConfig(record) {
      this.updateConfigVisible = true
      this.configFormData.hostName = record.hostName
      this.configFormData.hostId = record.ID
      this.configFormData.configId = record.configId === 0 ? '无' : record.configId
      // TODO 获取当前配置id以及名称
    },

    async getAllConfig() {
      const { data } = await getConfigs({
        status: true,
        pageNum: 1,
        pageSize: 100
      })
      const tmp = data.list
      for (let i = 0; i < tmp.length; i++) {
        this.allConfigs.push({ ID: tmp[i].ID, name: tmp[i].name })
      }
    },

    closeConfigForm() {
      this.updateConfigVisible = false
      this.$refs['configDialogForm'].resetFields()
      this.getTableData()
    },

    submitConfigPushForm() {
      this.$refs['configDialogForm'].validate(async valid => {
        if (valid) {
          this.submitConfigPushLoading = true
          try {
            let response = await updateConfig({
              id: this.configFormData.hostId,
              hostName: this.configFormData.hostName,
              configId: this.configFormData.configId
            })
            let messageType = response.code === 200 ? 'success' : 'error'
            this.$message({
              showClose: true,
              message: response.message,
              type: messageType
            })
            response = await pushConfig(
              {
                hostNames: [this.configFormData.hostName],
                configId: this.configFormData.configId
              }
            )
            messageType = response.code === 200 ? 'success' : 'error'
            this.$message({
              showClose: true,
              message: response.message,
              type: messageType
            })
          } finally {
            this.submitConfigPushLoading = false
            this.closeConfigForm()
          }
        } else {
          this.$message({
            showClose: true,
            message: '表单校验失败',
            type: 'error'
          })
          return false
        }
      })
    },

    // 批量删除
    batchDelete() {
      this.$confirm('此操作将永久删除, 是否继续?', '提示', {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }).then(async res => {
        this.loading = true
        const configIds = []
        this.multipleSelection.forEach(x => {
          configIds.push(x.ID)
        })
        let msg = ''
        try {
          const { message } = await batchDeleteHost({ ids: configIds })
          msg = message
        } finally {
          this.loading = false
        }

        await this.getTableData()
        this.$message({
          showClose: true,
          message: msg,
          type: 'success'
        })
      }).catch(() => {
        this.$message({
          showClose: true,
          type: 'info',
          message: '已取消删除'
        })
      })
    },

    // 批量更新
    batchUpdate() {

    },

    // 表格多选
    handleSelectionChange(val) {
      this.multipleSelection = val
    },
    // 分页
    handleSizeChange(val) {
      this.params.pageSize = val
      this.getTableData()
    },
    handleCurrentChange(val) {
      this.params.pageNum = val
      this.getTableData()
    },

    // process table
    showHostAndProcessDetail(row) {
      this.showProcessInfoVisible = true
      this.currentHostName = row.hostName
      this.getProcessTable()
    },
    // 分页
    processHandleSizeChange(val) {
      this.processParams.pageSize = val
      this.getProcessTable()
    },
    processHandleCurrentChange(val) {
      this.processParams.pageNum = val
      this.getProcessTable()
    },
    // 关闭配置创建
    closeProcessInfoVisible() {
      this.showProcessInfoVisible = false
      this.currentHostName = ''
    },
    getAgentStatusColor(type) {
      if (type === 'success inject' || type === 'success degrade') {
        return 'success'
      } else if (type === 'not inject') {
        return 'primary'
      } else if (type === 'failed inject' || type === 'failed uninstall agent' || type === 'failed degrade') {
        return 'danger'
      }
    },
    getAgentStatusText(type) {
      if (type === 'success inject' || type === 'success degrade') {
        return '防护中'
      } else if (type === 'not inject') {
        return '未安装'
      } else if (type === 'failed inject' || type === 'failed uninstall agent' || type === 'failed degrade') {
        return '安装失败'
      }
    },
    dateFormat(row, column) {
      const date = row[column.property]
      if (date === undefined) {
        return ''
      }
      return moment(date).format('YYYY-MM-DD HH:mm:ss')
    },
    getAgentMode(mode) {
      switch (mode) {
        case 'static':
          return { value: '静态', color: '' }
        case 'dynamic':
          return { value: '动态', color: 'success' }
        case 'disable':
          return { value: '禁用', color: 'info' }
        case '':
          return { value: '全部', color: '' }
        default:
          return { value: '未知', color: 'danger' }
      }
    },
    isOnline(d1) {
      const t1 = new Date(d1)
      const t2 = new Date()
      const diff = t2 - t1
      return diff <= 5 * 60 * 1000
    },
    getConfigNameById(configId) {
      const matches = this.allConfigs.filter((item) => { return item.ID === configId })
      if (matches.length > 0) {
        return matches[0].name
      } else {
        return '无'
      }
    }
  }
}
</script>

<style scoped>
</style>
